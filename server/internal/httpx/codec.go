// Package httpx holds HTTP helpers shared across the V4 API handlers:
// protobuf request/response codecs and a uniform error writer. Extracted in
// V4-S2 once both auth and profile needed the same wire plumbing.
package httpx

import (
	"fmt"
	"io"
	"net/http"

	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	"google.golang.org/protobuf/proto"
)

// ContentTypeProtobuf is the wire format for the V4 HTTP API. Kept identical to
// the WS frame payload in V4-S3 so the codec is shared between HTTP and WS.
const ContentTypeProtobuf = "application/x-protobuf"

// MaxBodyBytes caps request bodies (16 KiB is plenty for our messages and
// prevents accidental DoS through giant payloads).
const MaxBodyBytes = 16 * 1024

// ReadProto reads and unmarshals a length-capped protobuf request body.
func ReadProto(r *http.Request, m proto.Message) error {
	body, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, MaxBodyBytes))
	if err != nil {
		return fmt.Errorf("read body: %w", err)
	}
	return proto.Unmarshal(body, m)
}

// WriteProto marshals m and writes it with the given HTTP status.
func WriteProto(w http.ResponseWriter, status int, m proto.Message) {
	body, err := proto.Marshal(m)
	if err != nil {
		http.Error(w, "marshal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", ContentTypeProtobuf)
	w.WriteHeader(status)
	_, _ = w.Write(body)
}

// WriteError writes a uniform ErrorResp (msg_id = ERROR_RESP) with an HTTP status.
// detail is developer-facing context, not shown directly to players.
func WriteError(w http.ResponseWriter, status int, code pbcommon.ErrorCode, detail string, inReplyTo pbcommon.MsgId) {
	WriteProto(w, status, &pbcommon.ErrorResp{
		Code:      code,
		Detail:    detail,
		InReplyTo: inReplyTo,
	})
}
