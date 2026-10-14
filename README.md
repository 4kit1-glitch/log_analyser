# Log Analyser
Author: Kengah Ireneaus

A lightweight Bash-based project for scanning application logs, compressing repeated events, identifying unhealthy patterns, and producing a fast verdict about service health.

This tool is designed for operational triage: it helps answer questions such as whether a log sequence looks healthy, degraded, or critical without needing to manually read every line.

---

## Overview

The project reads one or more log files from a directory, normalizes their entries, and then inspects the sequence of events to determine whether the system is:

- healthy and stable,
- warning-level degraded,
- or in a critical/failing state.

It does this using a combination of:

- file discovery,
- structured parsing,
- severity weighting,
- repetitive log compression,
- manual rule-based analysis,
- and an optional AI-assisted overview.

The project is intentionally built as a practical CLI tool rather than a sprawling enterprise logging stack. It focuses on clarity, portability, and a strong signal-to-noise ratio for operational review.

---

## Why this project exists

A simple count of log lines is misleading. A service that logged 99 successful requests and one fatal failure is not healthy. It is unstable. The problem is not just counting events; it is understanding state, severity, and event ordering.

This project tries to avoid the common false impression created by naive log scanning by:

- identifying the most severe event that matters,
- tracking whether the system recovered or ended in failure,
- recognizing startup and shutdown patterns,
- reducing repeated noise using compression,
- and surfacing context around the last critical event.

---

## Required log format and limitations

This tool expects log entries to be plain text, single-line records with a predictable structure.

### Supported pattern

The intended format is:

```text
2026-09-27 15:26:59 [INFO] app: backup completed in 47s
```

The parser works most reliably when each line follows this form:

```text
YYYY-MM-DD HH:MM:SS [LEVEL] logger: message
```

The project also compresses repeated entries into a compact representation like:

```text
2026-09-27 08:00:15 - 2026-09-27 08:00:30|INFO|api|/health returned 200 x2
```

This means the generator and analyser are designed around a simple operational log schema:

- timestamp in ISO-style date and time,
- severity level in brackets,
- logger or subsystem name,
- a message body with human-readable state details.

### Important limitations

This tool is intentionally narrow and should be used in that scope.

1. One event per line
   - Multiline stack traces and JSON blobs are not first-class inputs.
   - If the log includes wrapped exceptions or multi-line payloads, the parser may not interpret them correctly.

2. Plain text format only
   - CSV, JSON logs, structured app telemetry, and database-backed logs are outside the intended scope.

3. Severity labels must be recognizable
   - Typical accepted values include INFO, DEBUG, WARN, ERROR, CRITICAL, and FATAL.
   - Custom severity naming may not be recognized unless it matches the keyword lists used by the scripts.

4. No arbitrary parser for every vendor format
   - The project is optimized for application logs with a similar structure to the sample files in the repository.
   - This is not a full log ingestion framework or SIEM.

5. No real-time streaming
   - It is a batch-analysis tool, not a live tailing or monitoring daemon.

6. Limited AI scope
   - The AI module is optional and intended for ambiguous cases, not as a replacement for a robust operational workflow.

---

## AI overview and current TUI status

The project includes an AI-assisted verdict pathway through the logic in [lib/05_ai_analyser.sh](lib/05_ai_analyser.sh), but the AI overview is not yet fully incorporated into the TUI experience as a first-class, polished interface.

At present, the flow is best understood as:

- the system performs a rule-based manual analysis,
- it can optionally send compressed log context to an AI model,
- and it may print a textual AI verdict summary,
- but the terminal UI is still primarily a shell-style summary rather than a complete interactive AI dashboard.

In other words, the AI capability exists as a useful operational extension, but the final TUI experience is not yet a fully integrated AI-driven console interface.

This is a deliberate limitation and a good next milestone for the project.

---

## How the tool works

The flow is straightforward:

1. The user provides a directory of logs.
2. The script validates and discovers candidate log files.
3. Each file is compressed to reduce repetitive noise.
4. Manual analysis inspects startup, shutdown, warnings, errors, and fatal signals.
5. A verdict is produced based on severity and end-state.
6. An optional AI pass can review a compressed event slice for ambiguous cases.

This makes the tool particularly useful for binary-style operational triage: healthy vs degraded vs critical.

---

## Script-by-script breakdown

### Entry point

#### [la](la)
This is the main orchestrator for the project. It:

- sets global environment values,
- prompts for the log directory,
- validates the path,
- loads all library scripts,
- iterates through log files,
- compresses them,
- runs the manual analyser,
- optionally triggers AI analysis,
- and presents the final terminal output.

This file is the main control center for the whole project.

### Library modules

#### [lib/00_logging.sh](lib/00_logging.sh)
Provides the logging helper functions for the project. It defines the error and info message functions used throughout the scripts so that the tool can write operational diagnostics to a local log file as it runs.

#### [lib/01_dir_files.sh](lib/01_dir_files.sh)
Handles directory validation and file discovery. It confirms that a provided path is valid, readable, and traversable, and then finds all `.log` files inside it using a safe recursive search.

#### [lib/02_extractor.sh](lib/02_extractor.sh)
Performs file validation and simple extraction helpers. It checks that each file exists, is readable, and has content, and provides helper functions used to inspect the first and last lines of logs when needed.

#### [lib/03_compressor.sh](lib/03_compressor.sh)
This is the compression engine. It reads parsed log entries and merges consecutive identical log signatures into a compact line such as:

```text
2026-09-27 08:00:15 - 2026-09-27 08:00:30|INFO|api|/health returned 200 x2
```

This reduces noisy repetition while still preserving the key events. This is especially useful when many similar lines appear in a row.

#### [lib/04_manual_analyser.sh](lib/04_manual_analyser.sh)
Runs the rule-based verdict logic. It inspects the log for evidence of:

- startup events,
- shutdown events,
- warnings,
- errors,
- critical failures,
- and recovery patterns after fatal events.

This is the core “manual” analysis layer that produces the project’s practical outcome without needing AI.

#### [lib/05_ai_analyser.sh](lib/05_ai_analyser.sh)
Provides the optional AI-assisted review pipeline. It builds a compressed-log prompt, sends it to an AI endpoint, verifies the response shape, and extracts a verdict, confidence, reason, and suggestion. It handles network and response issues with retries and clear error reporting.

This module is useful when the system state is ambiguous or the log pattern is difficult to classify from rules alone.

#### [lib/06_tui.sh](lib/06_tui.sh)
Defines the terminal UI layer. It handles headers, statuses, manual analysis output, AI verdict display, and the final footer. It uses ANSI styling when supported and falls back gracefully to plain terminal output when necessary.

This is the presentation layer for the CLI experience.

### Feature modules and analyser logic

#### [feat/lineparser.awk](feat/lineparser.awk)
Parses the raw log entries into a normalized internal layout. It extracts the timestamp, log level, logger name, and message, which makes later processing much easier and more consistent.

#### [feat/manualanalyser.awk](feat/manualanalyser.awk)
Contains the actual rule logic for determining startup state, shutdown state, severity, and recovery. It interprets patterns such as startup messages, warnings, errors, and fatal or critical events.

#### [tests/test_results/log_generator.py](tests/test_results/log_generator.py)
Generates realistic synthetic logs in the same style as the sample files. This helps the project test parsing and analysis logic without needing live production logs.

### Test data

#### [tests/test_files](tests/test_files)
Contains sample log files used to validate the analyser. These examples include healthy, warning, bad, and critical scenarios.

Examples:

- HEALTHY.log
- WARN.log
- BAD.log

These files provide concrete examples of how the project expects logs to look and behave.

---

## Folder structure

```text
log_analyser/
├── la
├── LICENSE
├── README.md
├── logcompress.sh
├── feat/
│   ├── lineparser.awk
│   └── manualanalyser.awk
├── lib/
│   ├── 00_logging.sh
│   ├── 01_dir_files.sh
│   ├── 01_flag_parser.sh
│   ├── 02_extractor.sh
│   ├── 03_compressor.sh
│   ├── 04_manual_analyser.sh
│   ├── 05_ai_analyser.sh
│   └── 06_tui.sh
├── tests/
│   ├── test_files/
│   │   ├── BAD.log
│   │   ├── HEALTHY.log
│   │   └── WARN.log
│   ├── test_results/
│   │   ├── log_generator.py
│   │   ├── test.awk
│   │   ├── t.sh
│   │   ├── ttt.sh
│   │   └── tt.sh
│   └── ...
└── docs/
    └── demo/
        ├── overview.png
        ├── tui.png
        └── verdict.png
```

> The docs/demo directory is a placeholder for future screenshots and project examples.

---

## Demo pictures

This project is ready for visual documentation. Add screenshots here as the project evolves.

### Placeholder gallery

```text
![Demo overview placeholder](docs/demo/overview.png)
![TUI placeholder](docs/demo/tui.png)
![Verdict output placeholder](docs/demo/verdict.png)
```

These placeholders are intended for future UI and output snapshots, such as:

- directory scan overview,
- terminal output in normal mode,
- AI verdict summary,
- and examples of healthy vs critical verdicts.

---

## Running the project

From the repository root:

```bash
./la
```

The tool will prompt for the directory containing the logs and ask whether AI-assisted analysis should be enabled.

---

## License

This project is distributed under the MIT License.

See the [LICENSE](LICENSE) file for the full legal terms.

---

## Project status

This project is a practical shell-based log triage utility that focuses on clarity, resilience, and fast operational insight. It is best described as a focused engineering tool for reading logs, identifying failure paths, and summarizing system health.

It is intentionally simple, portable, and transparent. That simplicity is also its strength.

---

## Future improvements

Potential future directions include:

- richer TUI integration for AI results,
- more advanced log format detection,
- structured JSON parsing,
- severity classification by regex configuration,
- exportable reports in Markdown or JSON,
- and a stronger dashboard look for human operators.

This project is already useful for small operational workflows, and it is a strong foundation for further extension.

---

## 8. Build Order

1. Dir Finder
2. File Walker
3. Extractor
4. Parser
5. Aggregator
6. Decision Engine
7. Reporter
8. Config loader
9. Context Slicer
10. AI Layer (last)

Each module tested independently before wiring together.

---

## 9. Dependencies

- Bash 4+
- Coreutils: `find`, `grep`, `sed`, `awk`, `sort`, `uniq`, `cut`, `head`, `tail`
- Optional: `jq` (JSON output), `curl` (AI layer)

No Python. No Node. Pure shell.

---