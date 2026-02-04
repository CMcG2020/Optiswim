package com.optiswim

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.vectorResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.optiswim.ui.screens.HomeScreen
import com.optiswim.ui.screens.LocationsScreen
import com.optiswim.ui.screens.SettingsScreen
import com.optiswim.ui.theme.OptiSwimTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            OptiSwimTheme {
                OptiSwimApp()
            }
        }
    }
}

private data class NavItem(
    val route: String,
    val label: String,
    val icon: Int
)

@Composable
private fun OptiSwimApp() {
    val navController = rememberNavController()
    val items = listOf(
        NavItem("home", "Home", R.drawable.ic_home),
        NavItem("locations", "Locations", R.drawable.ic_locations),
        NavItem("settings", "Settings", R.drawable.ic_settings)
    )

    Scaffold(
        bottomBar = {
            Box(modifier = Modifier.fillMaxWidth()) {
                Surface(
                    modifier = Modifier
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                        .fillMaxWidth(),
                    shape = RoundedCornerShape(28.dp),
                    tonalElevation = 6.dp,
                    shadowElevation = 6.dp,
                    color = MaterialTheme.colorScheme.surface
                ) {
                    NavigationBar(
                        containerColor = Color.Transparent,
                        tonalElevation = 0.dp
                    ) {
                        val navBackStackEntry by navController.currentBackStackEntryAsState()
                        val currentDestination = navBackStackEntry?.destination
                        items.forEach { item ->
                            val selected = currentDestination?.hierarchy?.any { it.route == item.route } == true
                            NavigationBarItem(
                                selected = selected,
                                onClick = {
                                    navController.navigate(item.route) {
                                        launchSingleTop = true
                                        restoreState = true
                                        popUpTo(navController.graph.startDestinationId) {
                                            saveState = true
                                        }
                                    }
                                },
                                icon = {
                                    androidx.compose.material3.Icon(
                                        imageVector = ImageVector.vectorResource(id = item.icon),
                                        contentDescription = item.label
                                    )
                                },
                                label = { Text(item.label) }
                            )
                        }
                    }
                }
            }
        }
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = "home",
        ) {
            composable("home") {
                HomeScreen(padding = padding, viewModel = hiltViewModel())
            }
            composable("locations") {
                val locationsViewModel = hiltViewModel<com.optiswim.ui.viewmodel.LocationsViewModel>()
                LocationsScreen(
                    padding = padding,
                    viewModel = locationsViewModel,
                    onSelectLocation = {
                        navController.navigate("home") {
                            launchSingleTop = true
                            restoreState = true
                            popUpTo(navController.graph.startDestinationId) {
                                saveState = true
                            }
                        }
                    },
                    onUseCurrentLocation = {
                        navController.navigate("home") {
                            launchSingleTop = true
                            restoreState = true
                            popUpTo(navController.graph.startDestinationId) {
                                saveState = true
                            }
                        }
                    }
                )
            }
            composable("settings") {
                SettingsScreen(padding = padding, viewModel = hiltViewModel())
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun OptiSwimAppPreview() {
    OptiSwimTheme {
        MaterialTheme {
            Text("OptiSwim")
        }
    }
}
