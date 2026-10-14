# analyser.awk - manual log analyser, one pass over the log.
#
# Log format assumed:  DATE TIME [LEVEL] logger: message
#
# Expected -v variables (set by analyse_log.sh):
#   start_kw  regex for a startup message   head_n  lines checked for startup
#   stop_kw   regex for a shutdown message  tail_n  lines checked for shutdown
#
function dn(y, m, d) {            # day number, handles month/year rollover
    if (m < 3) { y--; m += 12 }
    return 365*y + int(y/4) - int(y/100) + int(y/400) + int((153*(m-3)+2)/5) + d
}

NF == 0 { next }                  # skip blank lines

NF < 4 { unparsed++; next }       # lines that do not fit the format

{
    n++                           # counts non-blank parsed lines
    level = $3; gsub(/[][]/, "", level)
    msg = $0
    sub(/^[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +/, "", msg)
    low = tolower(msg)

    split($1, D, "-"); split($2, T, ":")
    t = dn(D[1]+0, D[2]+0, D[3]+0) * 86400 + T[1]*3600 + T[2]*60 + T[3]
    if (n == 1) { first_t = t; first_ts = $1 " " $2 }
    last_t = t; last_ts = $1 " " $2

    ring[n % tail_n] = $0         # keep the last tail_n lines
    lvl_ring[n % tail_n] = level
    low_ring[n % tail_n] = low
}

# ---- Q1: start ----
n <= head_n && start_verdict == "" {
    if (level == "INFO" && low ~ start_kw) {
        start_verdict = "STARTED"; start_ev = $0
    } else if (level == "ERROR" || level == "FATAL") {
        start_verdict = "FAILED"; start_ev = $0
    }
}

# ---- Q2: warnings ----
level == "WARN" {
    warns++
    wmin[substr($1 " " $2, 1, 16)]++
}

# ---- Q3: fatal and recovery (judged on the LAST fatal) ----
level == "FATAL" {
    fatals++
    fatal_line = $0
    after = 0; restarted = 0; errs_after_restart = 0; restart_line = ""
    next_is_after = 1
    next
}
next_is_after {
    after++
    if (!restarted && level == "INFO" && low ~ start_kw) {
        restarted = 1; restart_line = $0
    } else if (restarted && (level == "ERROR" || level == "FATAL")) {
        errs_after_restart++
    }
}

END {
    if (n == 0) { print "No parsable log lines."; exit 1 }

    span = last_t - first_t
    printf "Log span: %s -> %s (%d lines", first_ts, last_ts, n
    if (unparsed) printf ", %d unparsed", unparsed
    print ")\n"

    # Q1
    if (start_verdict == "") start_verdict = "UNKNOWN"
    printf "1. Startup:  %s\n", start_verdict
    if (start_ev != "") printf "     evidence: %s\n", start_ev
    else printf "     no startup message or error in the first %d lines\n", head_n

    # Q2
    printf "2. Warnings: %d total", warns
    if (span > 0) printf ", %.2f per minute on average", warns / (span / 60)
    print ""
    peak = 0
    for (k in wmin) if (wmin[k] > peak) { peak = wmin[k]; peak_k = k }
    if (peak > 0) printf "     peak: %d in the minute starting %s\n", peak, peak_k

    # Q3
    if (fatals == 0) {
        print "3. Fatal:    none in this log"
    } else {
        if (after == 0)
            v = "NOT RECOVERED (log ends at the FATAL)"
        else if (restarted && errs_after_restart == 0)
            v = "RECOVERED (restart seen, no errors since)"
        else if (restarted)
            v = "RESTARTED BUT UNSTABLE (" errs_after_restart " errors after restart)"
        else
            v = "UNKNOWN (log continues but no restart message seen)"
        printf "3. Fatal:    %d found, last one: %s\n", fatals, v
        printf "     fatal:   %s\n", fatal_line
        if (restart_line != "") printf "     restart: %s\n", restart_line
    }

    # Q4
    closed = 0
    for (i = 0; i < tail_n; i++)
        if (lvl_ring[i] == "INFO" && low_ring[i] ~ stop_kw) { closed = 1; stop_ev = ring[i] }
    if (closed) {
        print "4. Shutdown: CLEAN"
        printf "     evidence: %s\n", stop_ev
    } else {
        print "4. Shutdown: NO CLEAN SHUTDOWN SEEN (still running, or log is a slice)"
        printf "     last line: %s\n", ring[n % tail_n]
    }
}