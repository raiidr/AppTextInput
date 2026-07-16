package com.apptextinput

import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext

class AppTextInputViewManager : SimpleViewManager<AppEditText>() {
  override fun getName(): String = "AppTextInput"

  override fun createViewInstance(reactContext: ThemedReactContext): AppEditText {
    return AppEditText(reactContext)
  }
}
