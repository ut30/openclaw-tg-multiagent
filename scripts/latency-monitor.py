#!/usr/bin/env python3
# ==============================================================================
# Generalised Latency & Health Monitor
# Samples an HTTPS endpoint, tracks container performance, and logs alerts.
# ==============================================================================

import argparse
import time
import urllib.request
import urllib.error
import ssl
from datetime import datetime

def parse_args():
    parser = argparse.ArgumentParser(description="Latency and health monitor")
    parser.add_argument("--url", default="https://127.0.0.1/", help="Target endpoint to probe")
    parser.add_argument("--interval", type=int, default=5, help="Sample interval in seconds (default: 5)")
    parser.add_argument("--threshold-ms", type=float, default=50.0, help="Latency alert threshold in ms")
    parser.add_argument("--consecutive-alerts", type=int, default=3, help="Consecutive slow samples to trigger alert")
    parser.add_argument("--log-file", default="monitor.log", help="Path to write log entries")
    return parser.parse_args()

def log(msg, log_file):
    ts = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    line = f"[{ts}] {msg}"
    print(line)
    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception as e:
        print(f"Failed writing to log file: {e}")

def measure_latency(url, timeout=5):
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    start = time.time()
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "HealthMonitor/1.0"})
        with urllib.request.urlopen(req, context=ctx, timeout=timeout) as resp:
            elapsed_ms = (time.time() - start) * 1000
            return elapsed_ms, resp.status, None
    except urllib.error.HTTPError as e:
        elapsed_ms = (time.time() - start) * 1000
        return elapsed_ms, e.code, None
    except Exception as e:
        elapsed_ms = (time.time() - start) * 1000
        return elapsed_ms, None, str(e)

def main():
    args = parse_args()
    log(f"Starting latency monitor on {args.url} (threshold: {args.threshold_ms}ms)", args.log_file)
    consecutive_slow = 0

    try:
        while True:
            elapsed_ms, status, err = measure_latency(args.url)
            if err:
                log(f"ERROR: Probe failed ({err})", args.log_file)
                consecutive_slow += 1
            else:
                if elapsed_ms > args.threshold_ms:
                    consecutive_slow += 1
                    log(f"SLOW SAMPLE: {elapsed_ms:.2f}ms (HTTP {status}) [Count: {consecutive_slow}]", args.log_file)
                else:
                    consecutive_slow = 0
                    log(f"OK: {elapsed_ms:.2f}ms (HTTP {status})", args.log_file)

            if consecutive_slow >= args.consecutive_alerts:
                log(f"ALERT: {consecutive_slow} consecutive samples exceeded {args.threshold_ms}ms threshold!", args.log_file)

            time.sleep(args.interval)
    except KeyboardInterrupt:
        log("Latency monitor stopped by operator.", args.log_file)

if __name__ == "__main__":
    main()
