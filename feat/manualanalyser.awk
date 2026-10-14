# manualanalyser.awk - manual log analyser, one pass over the log.
#
# Log format assumed:  DATE TIME [LEVEL] logger: message
#
# Expected -v variables (set by manualanalyser.sh):
#   STARTUP_KEYWORDS  regex, startup message (matched on the message)
#   STOP_KEYWORDS     regex, shutdown message (matched on the message)
#   FATAL_KEYWORDS    regex, matched on the LEVEL token only
#   CRITICAL_KEYWORDS regex, matched on the LEVEL token only (own class,
#                     checked after FATAL, so keep these words out of FATAL_KEYWORDS)
#   ERROR_KEYWORDS    regex, matched on the LEVEL token only
#   WARN_KEYWORDS     regex, matched on the LEVEL token only
#   head_n / tail_n   lines checked for startup / shutdown
#
# Severity is read from the level token, never from the message, so a
# message like "Failed with result" on an INFO line is not counted as an error.

function dn(y, m, d) {            # day number, handles month/year rollover
    if (m < 3) { y--; m += 12 }
    return 365*y + int(y/4) - int(y/100) + int(y/400) + int((153*(m-3)+2)/5) + d
}

function sev(l) {                 # FATAL / CRITICAL / ERROR / WARN / OTHER
    l = tolower(l)
    if (l ~ fatal_re) return "FATAL"
    if (l ~ crit_re)  return "CRITICAL"
    if (l ~ error_re) return "ERROR"
    if (l ~ warn_re)  return "WARN"
    return "OTHER"
}

BEGIN {
    start_re = tolower(STARTUP_KEYWORDS); stop_re  = tolower(STOP_KEYWORDS)
    fatal_re = tolower(FATAL_KEYWORDS);   error_re = tolower(ERROR_KEYWORDS)
    warn_re  = tolower(WARN_KEYWORDS);    crit_re  = tolower(CRITICAL_KEYWORDS)
    if (start_re == "" || stop_re == "" || fatal_re == "" || crit_re == "" || error_re == "" || warn_re == "") {
        print "manualanalyser.awk: a *_KEYWORDS variable is empty" > "/dev/stderr"
        exit 2
    }
    if (head_n + 0 < 1 || tail_n + 0 < 1) {
        print "manualanalyser.awk: head_n and tail_n must be >= 1" > "/dev/stderr"
        exit 2
    }
}

NF == 0 { next }                  # skip blank lines
NF < 4  { unparsed++; next }      # lines that do not fit the format

{
    n++                           # counts non-blank parsed lines
    level = $3; gsub(/[][]/, "", level)
    s = sev(level)
    msg = $0
    sub(/^[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +/, "", msg)
    low = tolower(msg)

    split($1, D, "-"); split($2, T, ":")
    t = dn(D[1]+0, D[2]+0, D[3]+0) * 86400 + T[1]*3600 + T[2]*60 + T[3]
    if (n == 1) { first_t = t; first_ts = $1 " " $2 }
    last_t = t; last_ts = $1 " " $2

    ring[n % tail_n]     = $0     # keep the last tail_n lines
    sev_ring[n % tail_n] = s
    low_ring[n % tail_n] = low
}

# ---- Q1: start ----
n <= head_n && start_verdict == "" {
    if (s == "OTHER" && low ~ start_re) {
        start_verdict = "STARTED"; start_ev = $0
    } else if (s == "ERROR" || s == "CRITICAL" || s == "FATAL") {
        start_verdict = "FAILED"; start_ev = $0
    }
}

# ---- Q2: warnings ----
s == "WARN" {
    warns++
    wmin[substr($1 " " $2, 1, 16)]++
}

# ---- critical (own class, does not mean the process died) ----
s == "CRITICAL" {
    crits++
    if (crits == 1) crit_first = $0
    crit_last = $0
}

# ---- Q3: fatal and recovery (judged on the LAST fatal) ----
s == "FATAL" {
    fatals++
    fatal_line = $0
    after = 0; restarted = 0; errs_after_restart = 0; restart_line = ""
    seen_fatal = 1
    next                          # the FATAL line itself is not "after" itself
}
seen_fatal {
    after++
    if (!restarted && s == "OTHER" && low ~ start_re) {
        restarted = 1; restart_line = $0
    } else if (restarted && (s == "ERROR" || s == "CRITICAL" || s == "FATAL")) {
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

    # Critical (separate from the fatal check)
    if (crits == 0) {
        print "   Critical: none in this log"
    } else {
        printf "   Critical: %d found\n", crits
        printf "     first: %s\n", crit_first
        if (crits > 1) printf "     last:  %s\n", crit_last
    }

    # Q4
    closed = 0
    for (i = 0; i < tail_n; i++)
        if (sev_ring[i] == "OTHER" && low_ring[i] ~ stop_re) { closed = 1; stop_ev = ring[i] }
    if (closed) {
        print "4. Shutdown: CLEAN"
        printf "     evidence: %s\n", stop_ev
    } else {
        print "4. Shutdown: NO CLEAN SHUTDOWN SEEN (still running, or log is a slice)"
        printf "     last line: %s\n", ring[n % tail_n]
    }
}