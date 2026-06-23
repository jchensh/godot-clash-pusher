# V4 Makefile — 根级总入口，覆盖 protobuf 生成 / Go 构建·测试 / docker compose / migrations。
#
# 推荐流程：
#   1. make install-tools       # 装 protoc-gen-go (一次)
#   2. make gen-proto-go        # 生成 Go pb (commit 入 git)
#   3. make up                  # 起 pg+redis+server 三容器
#   4. make migrate             # 跑 schema migrations
#   5. make test                # go test + godot 单测
#   6. make down                # 停容器
#
# 兼容 GnuWin32 Make 3.81 (Windows winget) 的简单 GNU Make 语法。

.PHONY: help \
        gen-proto gen-proto-go gen-proto-gd \
        install-tools \
        build-go test-go vet-go fmt-go tidy-go \
        test-godot test \
        up down down-v logs ps migrate \
        clean

# Paths
PROTO_DIR  := proto
GO_PB_OUT  := server/internal/pb
GD_PB_OUT  := net/proto
PROTO_FILES := $(wildcard $(PROTO_DIR)/*.proto)

help:
	@echo "V4 Makefile targets:"
	@echo "  gen-proto-go    Generate Go protobuf code into $(GO_PB_OUT)/"
	@echo "  gen-proto-gd    Print instructions to regenerate GDScript pb (manual in Godot editor)"
	@echo "  gen-proto       Both of the above"
	@echo "  install-tools   Go install protoc-gen-go (one-shot)"
	@echo ""
	@echo "  build-go        go build ./... in server/"
	@echo "  test-go         go test  ./... in server/"
	@echo "  vet-go          go vet   ./... in server/"
	@echo "  fmt-go          gofmt -s -w server/"
	@echo "  tidy-go         go mod tidy in server/"
	@echo "  test-godot      Print godot unit test command (machine-specific exe)"
	@echo "  test            Combined Go + Godot tests"
	@echo ""
	@echo "  up              docker compose up -d --build (pg+redis+gateway+api+battle)"
	@echo "  down            docker compose down (keep pg volume)"
	@echo "  down-v          docker compose down -v (drop pg volume too)"
	@echo "  logs            docker compose logs -f"
	@echo "  ps              docker compose ps"
	@echo "  migrate         Run server/cmd/migrate inside compose stack"
	@echo "  clean           Remove server/bin/ and pb generated artifacts"

# ---------------- Protobuf ----------------

gen-proto: gen-proto-go gen-proto-gd

gen-proto-go:
	@echo ">> Generating Go protobuf -> $(GO_PB_OUT)/<subpkg>/"
	@mkdir -p $(GO_PB_OUT)
	@# module= strips the prefix from each go_package -> relative output path under --go_out.
	@# Layout: pb/common/common.pb.go, pb/auth/auth.pb.go, ...
	@protoc \
	    --proto_path=$(PROTO_DIR) \
	    --go_out=$(GO_PB_OUT) \
	    --go_opt=module=github.com/jchensh/godot-clash-pusher/server/internal/pb \
	    $(PROTO_FILES)
	@echo "OK"

gen-proto-gd:
	@echo ">> GDScript protobuf is generated INSIDE the Godot editor by the godobuf plugin."
	@echo "   1. Open Godot editor"
	@echo "   2. Project > Tools > Godobuf > select proto/*.proto"
	@echo "   3. Output to $(GD_PB_OUT)/"
	@echo "   (godobuf has no headless CLI; this is a one-time manual step per schema change.)"

install-tools:
	@echo ">> go install protoc-gen-go (latest)"
	@go install google.golang.org/protobuf/cmd/protoc-gen-go@latest

# ---------------- Go ----------------

build-go:
	@cd server && go build ./...

test-go:
	@cd server && go test ./...

vet-go:
	@cd server && go vet ./...

fmt-go:
	@cd server && gofmt -s -w .

tidy-go:
	@cd server && go mod tidy

# ---------------- Godot tests ----------------

test-godot:
	@echo ">> Godot unit tests (Windows: substitute 'godot' with the godot exe path)"
	@echo "   HOME=/private/tmp/godot-home godot --headless --path . --script res://tests/test_runner.gd"

test: test-go test-godot

# ---------------- Docker Compose ----------------
# All compose commands run from server/ so the compose file + Dockerfile context align.

up:
	@cd server && docker compose up -d --build

down:
	@cd server && docker compose down

down-v:
	@cd server && docker compose down -v

logs:
	@cd server && docker compose logs -f

ps:
	@cd server && docker compose ps

migrate:
	@cd server && docker compose run --rm gateway /usr/local/bin/migrate

# ---------------- Housekeeping ----------------

clean:
	@rm -rf server/bin/
	@rm -rf $(GO_PB_OUT)/*.pb.go
	@echo "cleaned"
