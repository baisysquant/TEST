#!/bin/bash
#========================[=======================================================](https://ns1.getesa.gq/access/retrieve/sZuqYI5Unr_ZRGgJ2iD18FDqutqfp4t3ghQXy2DdKXM) 
# scp_cdr_backup.sh
#
# 扫描本脚本所在目录下的 cbs_cdr*.add 话单, 按文件名中的节点号分流并 scp 到
# 目标端 backup 目录; 仅处理文件名日期在 20260927~20261014(含) 期间的话单。
#
#   文件名含 162 -> inv@10.22.0.45:/onip/invcdr155_mount/output/pps/normal/backup
#   文件名含 169 -> inv@10.22.0.45:/onip/invcdr156_mount/output/pps/normal/backup
#
# 说明:
#   * 源文件不删除, 仅复制(安全, 可重复执行)。
#   * 认证: 口令写在本脚本内。优先用 sshpass; 没有则用 SSH_ASKPASS + setsid
#     回退(已把 stdin 重定向为 /dev/null, 兼容 OpenSSH 7.x 不读 askpass 的情况)。
#   * 目标目录不存在时自动创建(mkdir -p)。
#
# 用法:
#   bash scp_cdr_backup.sh            正常执行
#   DRY_RUN=true bash scp_cdr_backup.sh   只列出将要传输的文件, 不实际传输
#===============================================================================
set -uo pipefail
export LC_ALL=C

# ---------------------------- 配置 -------------------------------------------
DST_HOST="10.22.0.45"
DST_USER="inv"
DST_PASS='I#nv_0001'
DST_PORT=22

DATE_FROM="20260927"
DATE_TO="20261014"

BACKUP_162="/onip/invcdr155_mount/output/pps/normal/backup"
BACKUP_169="/onip/invcdr156_mount/output/pps/normal/backup"

CHUNK=200              # 每次 scp 传输的文件数(避免命令行超长)
CONNECT_TIMEOUT=20
DRY_RUN="${DRY_RUN:-false}"
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_PREFIX="$(basename "$0")"

log()  { printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$LOG_PREFIX" "$*"; }
die()  { log "ERROR: $*" >&2; exit 1; }
is_true() { case "$1" in [Tt]*|[Yy]*|1) return 0 ;; *) return 1 ;; esac; }

SSH_BIN="$(command -v ssh 2>/dev/null || true)"
SCP_BIN="$(command -v scp 2>/dev/null || true)"
[ -n "$SCP_BIN" ] || die "未找到 scp, 请确认 openssh-clients 已安装"

# ---------------------------- 认证前缀 ---------------------------------------
CONN_PREFIX=( env )        # 非空数组, 避免 set -u + 空数组展开问题
ASKPASS_MODE=0
TMP_AUTH=""

setup_auth() {
    local sshpass_bin setsid_bin
    sshpass_bin="$(command -v sshpass 2>/dev/null || true)"
    setsid_bin="$(command -v setsid 2>/dev/null || true)"
    if [ -n "$sshpass_bin" ]; then
        CONN_PREFIX=( "$sshpass_bin" -p "$DST_PASS" )
        ASKPASS_MODE=0
        log "认证方式: sshpass"
    elif [ -n "$setsid_bin" ]; then
        TMP_AUTH="$(mktemp -d "${TMPDIR:-/tmp}/scp_cdr.XXXXXX")" || die "无法创建临时目录"
        local pass_file="$TMP_AUTH/.pass" ask_file="$TMP_AUTH/.askpass"
        printf '%s' "$DST_PASS" > "$pass_file"
        chmod 600 "$pass_file" 2>/dev/null || true
        printf '#!/bin/sh\ncat %s\n' "$pass_file" > "$ask_file"
        chmod 700 "$ask_file" 2>/dev/null || true
        CONN_PREFIX=( env "SSH_ASKPASS=$ask_file" "SSH_ASKPASS_REQUIRE=force"
                      "DISPLAY=:0" "$setsid_bin" -w )
        ASKPASS_MODE=1
        trap 'rm -rf "$TMP_AUTH"' EXIT
        log "认证方式: SSH_ASKPASS + setsid (无 sshpass)"
    else
        die "口令认证需要 sshpass 或 setsid, 请安装: yum install -y sshpass"
    fi
}

# 追加到 ssh/scp 的通用选项(目标端 host key 不做校验, 适配一次性搬运)
common_opts() {
    SSH_OPTS=( -p "$DST_PORT" -o "ConnectTimeout=$CONNECT_TIMEOUT" -o LogLevel=ERROR
               -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
               -o ServerAliveInterval=15 -o ServerAliveCountMax=3 )
    SCP_OPTS=( -P "$DST_PORT" -o "ConnectTimeout=$CONNECT_TIMEOUT" -o LogLevel=ERROR
               -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
               -o ServerAliveInterval=15 -o ServerAliveCountMax=3 )
}

# ssh <命令>   —— askpass 模式下必须让 stdin 不是 tty, 否则 OpenSSH 7.x 不读 askpass
run_ssh() {
    if [ "$ASKPASS_MODE" = "1" ]; then
        "${CONN_PREFIX[@]}" "$SSH_BIN" "${SSH_OPTS[@]}" "$DST_USER@$DST_HOST" "$1" < /dev/null
    else
        "${CONN_PREFIX[@]}" "$SSH_BIN" "${SSH_OPTS[@]}" "$DST_USER@$DST_HOST" "$1"
    fi
}

# scp <目标目录> <文件...>
run_scp() {
    local dest="$1"; shift
    if [ "$ASKPASS_MODE" = "1" ]; then
        "${CONN_PREFIX[@]}" "$SCP_BIN" "${SCP_OPTS[@]}" "$@" "$DST_USER@$DST_HOST:$dest" < /dev/null
    else
        "${CONN_PREFIX[@]}" "$SCP_BIN" "${SCP_OPTS[@]}" "$@" "$DST_USER@$DST_HOST:$dest"
    fi
}

# ---------------------------- 扫描 -------------------------------------------
# 从文件名里取出第一段连续 8 位数字(YYYYMMDD), 不在区间内则跳过。
FILES_162=()
FILES_169=()

scan() {
    local f base d
    while IFS= read -r -d '' f; do
        base="$(basename "$f")"
        if [[ "$base" =~ ([0-9]{8}) ]]; then
            d="${BASH_REMATCH[1]}"
        else
            continue                      # 文件名无 8 位日期, 不处理
        fi
        # shellcheck disable=SC2071  # YYYYMMDD 为等长补零字符串, 字典序比较即日期比较
        if [[ "$d" < "$DATE_FROM" || "$d" > "$DATE_TO" ]]; then
            continue                      # 日期不在 20260927~20261014 区间
        fi
        if [[ "$base" == *162* && "$base" == *169* ]]; then
            log "WARN: 同时含 162 与 169, 无法判定归属, 跳过: $base"
        elif [[ "$base" == *162* ]]; then
            FILES_162+=( "$f" )
        elif [[ "$base" == *169* ]]; then
            FILES_169+=( "$f" )
        fi
    done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name 'cbs_cdr*.add' -print0)
}

# ---------------------------- 传输 -------------------------------------------
# transfer <标签> <目标目录> <文件...>
transfer() {
    local label="$1" dest="$2"; shift 2
    local -a files=( "$@" )
    local total="${#files[@]}" ok=0 fail=0 i=0

    if [ "$total" -eq 0 ]; then
        log "[$label] 无符合条件的文件"
        return 0
    fi
    log "[$label] 共 $total 个待传输 -> $DST_USER@$DST_HOST:$dest"

    if is_true "$DRY_RUN"; then
        local f
        for f in "${files[@]}"; do log "[$label] DRY-RUN: $(basename "$f")"; done
        return 0
    fi

    # 确保目标目录存在
    if ! run_ssh "mkdir -p \"$dest\""; then
        log "ERROR: [$label] 无法创建目标目录 $dest"
        return 1
    fi

    while [ "$i" -lt "$total" ]; do
        local -a chunk=( "${files[@]:i:CHUNK}" )
        if run_scp "$dest" "${chunk[@]}" 2>/dev/null; then
            ok=$(( ok + ${#chunk[@]} ))
        else
            # 整批失败时逐个重试, 精确定位失败文件, 不影响其余文件
            local f
            for f in "${chunk[@]}"; do
                if run_scp "$dest" "$f" 2>/dev/null; then
                    ok=$(( ok + 1 ))
                else
                    fail=$(( fail + 1 ))
                    log "WARN: [$label] 传输失败: $(basename "$f")"
                fi
            done
        fi
        i=$(( i + CHUNK ))
    done

    log "[$label] 完成: 总数=$total 成功=$ok 失败=$fail"
    [ "$fail" -eq 0 ]
}

# ---------------------------- 主流程 -----------------------------------------
main() {
    log "脚本目录: $SCRIPT_DIR"
    log "日期区间: $DATE_FROM ~ $DATE_TO (含)"
    common_opts
    if is_true "$DRY_RUN"; then
        log "DRY-RUN 模式: 只列出将传输的文件, 不连接目标端(跳过认证)"
    else
        setup_auth
    fi

    scan
    log "扫描结果: 162=${#FILES_162[@]} 个, 169=${#FILES_169[@]} 个"

    local rc=0
    if [ "${#FILES_162[@]}" -gt 0 ]; then
        transfer "162" "$BACKUP_162" "${FILES_162[@]}" || rc=1
    else
        log "[162] 无符合条件的文件"
    fi
    if [ "${#FILES_169[@]}" -gt 0 ]; then
        transfer "169" "$BACKUP_169" "${FILES_169[@]}" || rc=1
    else
        log "[169] 无符合条件的文件"
    fi

    if [ "$rc" -eq 0 ]; then
        log "全部完成, 无失败文件"
    else
        log "存在传输失败的文件, 请查看上面的 WARN 日志; 源文件未删除, 可直接重试"
    fi
    return $rc
}

main "$@"
