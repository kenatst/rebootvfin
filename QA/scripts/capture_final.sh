#!/bin/bash
# Regenerates the final visual inventory. Usage: capture_final.sh <outdir> <locale-suffix>
cd "/Users/kena/Desktop/droit assurance/rebootvfin"
OUT="$1"
mkdir -p "$OUT"

cap_state () {
  xcrun simctl terminate "iPhone 17 Pro" com.kenatst.reboot 2>/dev/null
  sleep 0.7
  xcrun simctl launch "iPhone 17 Pro" com.kenatst.reboot -qaState "$PWD/QA/states/$1.json" >/dev/null
  sleep 3.4
  xcrun simctl io "iPhone 17 Pro" screenshot "$OUT/$2"
  echo "captured $2"
}

cap_seed () {
  xcrun simctl terminate "iPhone 17 Pro" com.kenatst.reboot 2>/dev/null
  sleep 0.7
  xcrun simctl launch "iPhone 17 Pro" com.kenatst.reboot -qaSeed "$1" >/dev/null
  sleep 3.8
  xcrun simctl io "iPhone 17 Pro" screenshot "$OUT/$2"
  echo "captured $2"
}

cap_state onboarding1 01_onboarding_page1.png
cap_state diagnosis_q0 08_diagnosis_q1_empty.png
cap_state diagnosis_q4 08_diagnosis_step4_multi.png
cap_state report_full 09_report_full.png
cap_seed day1     10_today_day01.png
cap_seed stay     11_today_day04_stay.png
cap_seed recall   12_today_day05_recall.png
cap_seed rest     13_today_recovery.png
cap_seed running  14_session_running.png
cap_seed done     15_session_done_day1.png
