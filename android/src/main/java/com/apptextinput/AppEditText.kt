package com.apptextinput

import android.content.Context
import androidx.appcompat.widget.AppCompatEditText

class AppEditText(context: Context) : AppCompatEditText(context) {
  init {
    // Placeholder for the editable Lottie-backed text input. The full
    // Fabric implementation will wire Codegen props, events, and a custom
    // ReplacementSpan for animated emoji.
  }
}
