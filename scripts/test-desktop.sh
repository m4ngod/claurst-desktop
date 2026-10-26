#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
. scripts/env.sh
cargo build --manifest-path vendor/claurst/src-rust/Cargo.toml -p claurst-acp -p claurst-tools --bin claurst-desktop-runtime --bin claurst-table-parser --locked
python3 scripts/prepare-latex.py --destination vendor/claurst/src-rust/target/debug/latex
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library desktop/Sources/DocumentParser/*.swift \
  -o vendor/claurst/src-rust/target/debug/claurst-document-parser
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskServiceTests.swift \
  -o .build-tools/task-service-test
.build-tools/task-service-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskControlTests.swift \
  -o .build-tools/task-control-test
.build-tools/task-control-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskHistoryTests.swift \
  -o .build-tools/task-history-test
.build-tools/task-history-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskCompactionTests.swift \
  -o .build-tools/task-compaction-test
.build-tools/task-compaction-test
.build-tools/task-compaction-test --overflow
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskOrganizeTests.swift \
  -o .build-tools/task-organize-test
.build-tools/task-organize-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskCommandTests.swift \
  -o .build-tools/task-command-test
.build-tools/task-command-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskCodingTests.swift \
  -o .build-tools/task-coding-test
.build-tools/task-coding-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskDocumentTests.swift \
  -o .build-tools/task-document-test
.build-tools/task-document-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskTableTests.swift \
  -o .build-tools/task-table-test
.build-tools/task-table-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskRecognitionTests.swift \
  -o .build-tools/task-recognition-test
.build-tools/task-recognition-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskVisionTests.swift \
  -o .build-tools/task-vision-test
.build-tools/task-vision-test
.build-tools/task-vision-test --timeout-only
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskImageReadTests.swift \
  -o .build-tools/task-image-read-test
.build-tools/task-image-read-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskWebTests.swift \
  -o .build-tools/task-web-test
.build-tools/task-web-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskSearchTests.swift \
  -o .build-tools/task-search-test
.build-tools/task-search-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskLatexTests.swift \
  -o .build-tools/task-latex-test
.build-tools/task-latex-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskResearchTests.swift \
  -o .build-tools/task-research-test
.build-tools/task-research-test

swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskPersonalizationTests.swift \
  -o .build-tools/task-personalization-test
.build-tools/task-personalization-test
swiftc -module-cache-path .build-tools/swift-cache -parse-as-library \
  desktop/Sources/DesktopCore/*.swift desktop/Tests/DesktopCoreTests/TaskTemporaryTests.swift \
  -o .build-tools/task-temporary-test
.build-tools/task-temporary-test
