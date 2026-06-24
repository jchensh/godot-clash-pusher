// Package matchmaking implements V4-S4 matchmaking: a Redis ZSET queue keyed by
// hidden ELO rating, plus a Matcher that pairs waiting players within an MMR
// window that widens the longer they wait. The pairing logic (Matcher) talks to
// an abstract Queue so it is unit-testable without Redis; RedisQueue is the
// production backend.
package matchmaking

import (
	"context"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
)

// Entry is one player waiting in the queue.
type Entry struct {
	AccountID int64
	MMR       int
	DeckSlot  int32
	JoinedAt  time.Time
}

// Queue stores waiting players. Implementations: RedisQueue (prod) + a fake in tests.
type Queue interface {
	Add(ctx context.Context, e Entry) error
	// All returns every waiting entry (MMR-ascending).
	All(ctx context.Context) ([]Entry, error)
	Remove(ctx context.Context, accountID int64) error
}

const (
	queueKey   = "matchmaking:queue" // ZSET: score = MMR, member = accountID
	metaPrefix = "matchmaking:meta:" // HASH per account: deck_slot, joined_at(ms)
)

func metaKey(accountID int64) string { return metaPrefix + strconv.FormatInt(accountID, 10) }

// RedisQueue is the production Queue backed by a Redis ZSET (+ per-account meta hash).
type RedisQueue struct {
	c *redis.Client
}

func NewRedisQueue(c *redis.Client) *RedisQueue { return &RedisQueue{c: c} }

func (q *RedisQueue) Add(ctx context.Context, e Entry) error {
	pipe := q.c.TxPipeline()
	pipe.ZAdd(ctx, queueKey, redis.Z{Score: float64(e.MMR), Member: e.AccountID})
	pipe.HSet(ctx, metaKey(e.AccountID), "deck_slot", e.DeckSlot, "joined_at", e.JoinedAt.UnixMilli())
	_, err := pipe.Exec(ctx)
	return err
}

func (q *RedisQueue) Remove(ctx context.Context, accountID int64) error {
	pipe := q.c.TxPipeline()
	pipe.ZRem(ctx, queueKey, accountID)
	pipe.Del(ctx, metaKey(accountID))
	_, err := pipe.Exec(ctx)
	return err
}

func (q *RedisQueue) All(ctx context.Context) ([]Entry, error) {
	zs, err := q.c.ZRangeByScoreWithScores(ctx, queueKey, &redis.ZRangeBy{Min: "-inf", Max: "+inf"}).Result()
	if err != nil {
		return nil, err
	}
	out := make([]Entry, 0, len(zs))
	for _, z := range zs {
		id, err := strconv.ParseInt(z.Member.(string), 10, 64)
		if err != nil {
			continue
		}
		meta, err := q.c.HGetAll(ctx, metaKey(id)).Result()
		if err != nil || len(meta) == 0 {
			// Meta missing (raced removal) — drop the stale ZSET member.
			_ = q.c.ZRem(ctx, queueKey, id).Err()
			continue
		}
		slot, _ := strconv.Atoi(meta["deck_slot"])
		joinedMs, _ := strconv.ParseInt(meta["joined_at"], 10, 64)
		out = append(out, Entry{
			AccountID: id,
			MMR:       int(z.Score),
			DeckSlot:  int32(slot),
			JoinedAt:  time.UnixMilli(joinedMs),
		})
	}
	return out, nil
}
