# HanguStep

Offline-first Korean learning app for iPhone, iPad and Mac. TOPIK I and II preparation with vocabulary, grammar, multiple-choice quizzes, mistake review, spaced repetition and iCloud sync. Content in Korean, English and Khmer.

Status: Phase 1 (architecture) in review. See `Documentation/ROADMAP.md` and `Documentation/PRD.md`.

Stack: Swift 6, SwiftUI, Clean Architecture + MVVM, Core Data, CloudKit. iOS 17+, macOS 14+.

## Build

```
cd Packages/HanguStepKit && swift test
xcodegen generate   # only after editing project.yml
open HanguStep.xcodeproj
```
