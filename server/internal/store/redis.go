package store

import (
	"context"
	"fmt"

	"github.com/redis/go-redis/v9"
)

// Redis wraps a go-redis client. V4-S4 is the first use of Redis (matchmaking
// queue); V4-S5 reuses it for leaderboards. Higher-level packages take the
// *redis.Client directly via Client().
type Redis struct {
	client *redis.Client
}

// OpenRedis dials and pings a Redis server. url is a redis:// URL, e.g.
// redis://localhost:6379/0.
func OpenRedis(ctx context.Context, url string) (*Redis, error) {
	opt, err := redis.ParseURL(url)
	if err != nil {
		return nil, fmt.Errorf("parse redis url: %w", err)
	}
	c := redis.NewClient(opt)
	if err := c.Ping(ctx).Err(); err != nil {
		_ = c.Close()
		return nil, fmt.Errorf("ping redis: %w", err)
	}
	return &Redis{client: c}, nil
}

func (r *Redis) Client() *redis.Client { return r.client }

func (r *Redis) Close() error { return r.client.Close() }
