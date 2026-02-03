package com.optiswim.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = OceanBlue,
    onPrimary = Color.White,
    secondary = Seafoam,
    onSecondary = DeepNavy,
    background = Color(0xFFF5F7FA),
    onBackground = DeepNavy,
    surface = Color.White,
    onSurface = DeepNavy
)

private val DarkColors = darkColorScheme(
    primary = Seafoam,
    onPrimary = DeepNavy,
    secondary = OceanBlue,
    onSecondary = Color.White,
    background = DeepNavy,
    onBackground = Color.White,
    surface = Color(0xFF0A2540),
    onSurface = Color.White
)

@Composable
fun OptiSwimTheme(content: @Composable () -> Unit) {
    val colors = if (isSystemInDarkTheme()) DarkColors else LightColors
    MaterialTheme(
        colorScheme = colors,
        typography = Typography,
        content = content
    )
}
