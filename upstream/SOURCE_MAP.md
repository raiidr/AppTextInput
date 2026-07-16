# Source Map

This document maps package files to the React Native source files that inspired them.

| Package file | Related React Native source | Purpose |
|---|---|---|
| `android/src/main/java/com/apptextinput/AppEditText.kt` | `ReactAndroid/src/main/java/com/facebook/react/views/textinput/ReactEditText.java` | Custom editable text view with Fabric/Codegen integration. |
| `android/src/main/java/com/apptextinput/AppTextInputViewManager.kt` | `ReactAndroid/src/main/java/com/facebook/react/views/textinput/ReactTextInputManager.java` | View manager that exposes props and commands to JavaScript. |
| `ios/AppTextInput/AppTextInputView.swift` | `React/Fabric/Mounting/ComponentViews/TextInput/RCTTextInputComponentView.mm` | Fabric component view backed by `UITextView`. |
| `ios/AppTextInput/AppTextInputViewManager.m` | `React/Views/RCTTextInputManager.m` | Legacy bridge view manager for development. |
| `src/components/AppTextInput.tsx` | `Libraries/Components/TextInput/TextInput.js` | Public JavaScript API and prop forwarding. |
| `src/utils/document.ts` | `Libraries/Text/Text.js` entity handling | Document model, UTF-16 offsets, and entity bookkeeping. |
