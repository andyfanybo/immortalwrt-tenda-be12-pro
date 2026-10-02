#!/usr/bin/env python3
"""Show concise build progress; detailed commands remain in the tee log."""
import argparse
from collections import deque
from pathlib import Path
import re
import sys

ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
ERROR = re.compile(
    r'fatal error:|\berror:|\bERROR:|undefined reference|cannot find -l|'
    r'No space left on device|Permission denied|Segmentation fault|'
    r'command not found|No such file or directory|\bKilled\b|out of memory|'
    r'\bFAILED:|\*\*\*.*\bError\b|build failed', re.I)
WRAPPER = re.compile(r'^make(?:\[\d+\])?:.*(?:\*\*\*|build failed)', re.I)
ENTER = re.compile(r"make(?:\[\d+\])?: Entering directory ['`]([^']+)")
TASK = re.compile(r'make(?:\[\d+\])?\s+-C\s+(\S+)\s+.*\b(compile|install|prepare|download)\b')


def clean(line):
    return ANSI.sub('', line).rstrip('\r\n')


def stream():
    seen = set()
    context = 0
    for raw in sys.stdin:
        line = clean(raw)
        entry = ENTER.search(line)
        task = TASK.search(line)
        scope = None
        if entry and '/openwrt/' in entry.group(1):
            scope = entry.group(1).split('/openwrt/', 1)[1]
        elif task:
            scope = task.group(1)
        if scope and scope.startswith(('tools/', 'toolchain/', 'package/', 'feeds/', 'target/')):
            if scope not in seen:
                print(f'compile {scope}', flush=True)
                seen.add(scope)
            continue
        if ERROR.search(line):
            print(line[:800], flush=True)
            context = 3
        elif context:
            # GCC source lines, caret markers and diagnostic continuation.
            if len(line) <= 800 and not line.startswith(('make', 'gcc ', 'g++ ', 'cc ', 'c++ ')):
                print(line, flush=True)
            context -= 1


def summary(paths):
    for path in paths:
        file = Path(path)
        if not file.is_file():
            continue
        print(f'--- {file.name}: 关键错误 ---')
        tail = deque(maxlen=20)
        previous = deque(maxlen=2)
        context = 0
        matches = 0
        emitted = 0
        with file.open(errors='replace') as log:
            for raw in log:
                line = clean(raw)
                tail.append(line)
                if emitted >= 100:
                    continue
                if ERROR.search(line) and not WRAPPER.search(line):
                    if context == 0:
                        for prior in previous:
                            if len(prior) <= 500:
                                print(prior)
                                emitted += 1
                    print(line[:800])
                    matches += 1
                    emitted += 1
                    context = 3
                elif context:
                    if len(line) <= 800:
                        print(line)
                        emitted += 1
                    context -= 1
                previous.append(line)
        if not matches:
            print('未匹配到编译器错误，以下为日志末尾：')
            for line in tail:
                print(line[:800])
        if emitted >= 100:
            print('更多诊断请查看完整日志附件。')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--summary', nargs='+', metavar='LOG')
    args = parser.parse_args()
    if args.summary:
        summary(args.summary)
    else:
        stream()
