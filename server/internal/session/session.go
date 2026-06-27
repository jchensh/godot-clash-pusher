// Package session manages persistent client connections. 决策 48 / V5-N1：进游戏
// 强制登录 + 持久 WS 会话，断线即不可玩。一账号一连接（新登录挤掉旧连接）。
package session

import "sync"

// Session is one connected client over a persistent WS.
type Session struct {
	AccountID int64
	send      chan []byte   // outbound frames（房间/经济推送复用，N3+）
	quit      chan struct{} // closed → 本会话停止（被新登录挤掉 / 关服）
	closeOnce sync.Once
}

func newSession(accountID int64) *Session {
	return &Session{AccountID: accountID, send: make(chan []byte, 32), quit: make(chan struct{})}
}

// stop signals this session to tear down. Idempotent.
func (s *Session) stop() { s.closeOnce.Do(func() { close(s.quit) }) }

// Manager tracks live sessions — one per account (newer login evicts the older).
type Manager struct {
	mu       sync.Mutex
	sessions map[int64]*Session
}

func NewManager() *Manager { return &Manager{sessions: map[int64]*Session{}} }

// register installs s as the account's live session, returning any evicted predecessor.
func (m *Manager) register(s *Session) (evicted *Session) {
	m.mu.Lock()
	defer m.mu.Unlock()
	evicted = m.sessions[s.AccountID]
	m.sessions[s.AccountID] = s
	return evicted
}

// unregister removes s only if it is still the live session (a newer login may have replaced it).
func (m *Manager) unregister(s *Session) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.sessions[s.AccountID] == s {
		delete(m.sessions, s.AccountID)
	}
}

// Get returns the live session for an account (nil if offline). Online-presence query.
func (m *Manager) Get(accountID int64) *Session {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.sessions[accountID]
}

// Count returns the number of live sessions (online players).
func (m *Manager) Count() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.sessions)
}
