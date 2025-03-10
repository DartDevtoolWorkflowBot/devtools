// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'example/conditional_screen.dart';
import 'framework/framework_core.dart';
import 'framework/initializer.dart';
import 'framework/landing_screen.dart';
import 'framework/notifications_view.dart';
import 'framework/release_notes/release_notes.dart';
import 'framework/scaffold.dart';
import 'screens/app_size/app_size_controller.dart';
import 'screens/app_size/app_size_screen.dart';
import 'screens/debugger/debugger_controller.dart';
import 'screens/debugger/debugger_screen.dart';
import 'screens/inspector/inspector_controller.dart';
import 'screens/inspector/inspector_screen.dart';
import 'screens/inspector/inspector_tree_controller.dart';
import 'screens/logging/logging_controller.dart';
import 'screens/logging/logging_screen.dart';
import 'screens/memory/memory_controller.dart';
import 'screens/memory/memory_screen.dart';
import 'screens/network/network_controller.dart';
import 'screens/network/network_screen.dart';
import 'screens/performance/performance_controller.dart';
import 'screens/performance/performance_screen.dart';
import 'screens/profiler/profiler_screen.dart';
import 'screens/profiler/profiler_screen_controller.dart';
import 'screens/provider/provider_screen.dart';
import 'screens/vm_developer/vm_developer_tools_controller.dart';
import 'screens/vm_developer/vm_developer_tools_screen.dart';
import 'service/service_extension_widgets.dart';
import 'shared/analytics/analytics.dart' as ga;
import 'shared/analytics/analytics_controller.dart';
import 'shared/analytics/metrics.dart';
import 'shared/common_widgets.dart';
import 'shared/console/primitives/simple_items.dart';
import 'shared/feature_flags.dart';
import 'shared/globals.dart';
import 'shared/offline_screen.dart';
import 'shared/primitives/auto_dispose.dart';
import 'shared/primitives/utils.dart';
import 'shared/routing.dart';
import 'shared/screen.dart';
import 'shared/theme.dart';
import 'shared/ui/hover.dart';
import 'standalone_ui/standalone_screen.dart';

// Assign to true to use a sample implementation of a conditional screen.
// WARNING: Do not check in this file if debugEnableSampleScreen is true.
const debugEnableSampleScreen = false;

// Disabled until VM developer mode functionality is added.
const showVmDeveloperMode = false;

/// Top-level configuration for the app.
@immutable
class DevToolsApp extends StatefulWidget {
  const DevToolsApp(
    this.screens,
    this.analyticsController, {
    super.key,
    this.sampleData = const [],
  });

  final List<DevToolsScreen> screens;
  final AnalyticsController analyticsController;
  final List<DevToolsJsonFile> sampleData;

  @override
  State<DevToolsApp> createState() => DevToolsAppState();
}

/// Initializer for the [FrameworkCore] and the app's navigation.
///
/// This manages the route generation, and marshals URL query parameters into
/// flutter route parameters.
// TODO(https://github.com/flutter/devtools/issues/1146): Introduce tests that
// navigate the full app.
class DevToolsAppState extends State<DevToolsApp> with AutoDisposeMixin {
  List<Screen> get _screens => widget.screens.map((s) => s.screen).toList();

  bool get isDarkThemeEnabled => _isDarkThemeEnabled;
  bool _isDarkThemeEnabled = true;

  bool get vmDeveloperModeEnabled => _vmDeveloperModeEnabled;
  bool _vmDeveloperModeEnabled = false;

  bool get denseModeEnabled => _denseModeEnabled;
  bool _denseModeEnabled = false;

  final hoverCardController = HoverCardController();

  late ReleaseNotesController releaseNotesController;

  late final routerDelegate = DevToolsRouterDelegate(_getPage);

  @override
  void initState() {
    super.initState();

    unawaited(ga.setupDimensions());

    addAutoDisposeListener(serviceManager.isolateManager.mainIsolate, () {
      setState(() {
        _clearCachedRoutes();
      });
    });

    _isDarkThemeEnabled = preferences.darkModeTheme.value;
    addAutoDisposeListener(preferences.darkModeTheme, () {
      setState(() {
        _isDarkThemeEnabled = preferences.darkModeTheme.value;
      });
    });

    _vmDeveloperModeEnabled = preferences.vmDeveloperModeEnabled.value;
    addAutoDisposeListener(preferences.vmDeveloperModeEnabled, () {
      setState(() {
        _vmDeveloperModeEnabled = preferences.vmDeveloperModeEnabled.value;
      });
    });

    _denseModeEnabled = preferences.denseModeEnabled.value;
    addAutoDisposeListener(preferences.denseModeEnabled, () {
      setState(() {
        _denseModeEnabled = preferences.denseModeEnabled.value;
      });
    });

    releaseNotesController = ReleaseNotesController();
  }

  @override
  void dispose() {
    // preferences is initialized in main() to avoid flash of content with
    // incorrect theme.
    preferences.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DevToolsApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clearCachedRoutes();
  }

  /// Gets the page for a given page/path and args.
  Page _getPage(
    BuildContext context,
    String? page,
    Map<String, String?> args,
    DevToolsNavigationState? state,
  ) {
    // Provide the appropriate page route.
    if (pages.containsKey(page)) {
      Widget widget = pages[page!]!(
        context,
        page,
        args,
        state,
      );
      assert(
        () {
          widget = _AlternateCheckedModeBanner(
            builder: (context) => pages[page]!(
              context,
              page,
              args,
              state,
            ),
          );
          return true;
        }(),
      );
      return MaterialPage(child: widget);
    }

    // Return a page not found.
    return MaterialPage(
      child: DevToolsScaffold.withChild(
        key: const Key('not-found'),
        embed: isEmbedded(args),
        child: CenteredMessage("'$page' not found."),
      ),
    );
  }

  Widget _buildTabbedPage(
    BuildContext _,
    String? page,
    Map<String, String?> params,
    DevToolsNavigationState? __,
  ) {
    final vmServiceUri = params['uri'];
    final embed = isEmbedded(params);

    // Always return the landing screen if there's no VM service URI.
    if (vmServiceUri?.isEmpty ?? true) {
      return DevToolsScaffold.withChild(
        key: const Key('landing'),
        embed: embed,
        child: LandingScreenBody(sampleData: widget.sampleData),
      );
    }

    // TODO(dantup): We should be able simplify this a little, removing params['page']
    // and only supporting /inspector (etc.) instead of also &page=inspector if
    // all IDEs switch over to those URLs.
    if (page?.isEmpty ?? true) {
      page = params['page'];
    }
    final hide = {...?params['hide']?.split(',')};
    return Initializer(
      url: vmServiceUri,
      allowConnectionScreenOnDisconnect: !embed,
      builder: (_) {
        // Force regeneration of visible screens when VM developer mode is
        // enabled.
        return ValueListenableBuilder<bool>(
          valueListenable: preferences.vmDeveloperModeEnabled,
          builder: (_, __, child) {
            final screens = _visibleScreens()
                .where((p) => embed && page != null ? p.screenId == page : true)
                .where((p) => !hide.contains(p.screenId))
                .toList();
            if (screens.isEmpty) return child ?? const SizedBox.shrink();
            return MultiProvider(
              providers: _providedControllers(),
              child: DevToolsScaffold(
                embed: embed,
                page: page,
                screens: screens,
                actions: [
                  // TODO(https://github.com/flutter/devtools/issues/1941)
                  if (serviceManager.connectedApp!.isFlutterAppNow!) ...[
                    const HotReloadButton(),
                    const HotRestartButton(),
                  ],
                  ...DevToolsScaffold.defaultActions(),
                ],
              ),
            );
          },
          child: DevToolsScaffold.withChild(
            embed: embed,
            child: CenteredMessage(
              page != null
                  ? 'The "$page" screen is not available for this application.'
                  : 'No tabs available for this application.',
            ),
          ),
        );
      },
    );
  }

  /// The pages that the app exposes.
  Map<String, UrlParametersBuilder> get pages {
    return _routes ??= {
      homeScreenId: _buildTabbedPage,
      for (final screen in widget.screens)
        screen.screen.screenId: _buildTabbedPage,
      snapshotScreenId: (_, __, args, ___) {
        final snapshotArgs = OfflineDataArguments.fromArgs(args);
        final embed = isEmbedded(args);
        return DevToolsScaffold.withChild(
          key: UniqueKey(),
          embed: embed,
          child: MultiProvider(
            providers: _providedControllers(offline: true),
            child: OfflineScreenBody(snapshotArgs, _screens),
          ),
        );
      },
      appSizeScreenId: (_, __, args, ____) {
        final embed = isEmbedded(args);
        return DevToolsScaffold.withChild(
          key: const Key('appsize'),
          embed: embed,
          child: MultiProvider(
            providers: _providedControllers(),
            child: const AppSizeBody(),
          ),
        );
      },
      if (FeatureFlags.vsCodeSidebarTooling) ..._standaloneScreens,
    };
  }

  Map<String, UrlParametersBuilder> get _standaloneScreens {
    return {
      for (final type in StandaloneScreenType.values)
        type.name: (_, __, args, ___) => type.screen,
    };
  }

  bool isEmbedded(Map<String, String?> args) => args['embed'] == 'true';

  Map<String, UrlParametersBuilder>? _routes;

  void _clearCachedRoutes() {
    _routes = null;
  }

  List<Screen> _visibleScreens() => _screens.where(shouldShowScreen).toList();

  List<Provider> _providedControllers({bool offline = false}) {
    return widget.screens
        .where(
          (s) => s.providesController && (offline ? s.supportsOffline : true),
        )
        .map((s) => s.controllerProvider(routerDelegate))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      themeMode: isDarkThemeEnabled ? ThemeMode.dark : ThemeMode.light,
      theme: themeFor(
        isDarkTheme: false,
        ideTheme: ideTheme,
        theme: ThemeData(useMaterial3: true, colorScheme: lightColorScheme),
      ),
      darkTheme: themeFor(
        isDarkTheme: true,
        ideTheme: ideTheme,
        theme: ThemeData(useMaterial3: true, colorScheme: darkColorScheme),
      ),
      builder: (context, child) {
        return MultiProvider(
          providers: [
            Provider<AnalyticsController>.value(
              value: widget.analyticsController,
            ),
            Provider<HoverCardController>.value(
              value: hoverCardController,
            ),
            Provider<ReleaseNotesController>.value(
              value: releaseNotesController,
            ),
          ],
          child: NotificationsView(
            child: ReleaseNotesViewer(
              controller: releaseNotesController,
              child: child,
            ),
          ),
        );
      },
      routerDelegate: routerDelegate,
      routeInformationParser: DevToolsRouteInformationParser(),
      // Disable default scrollbar behavior on web to fix duplicate scrollbars
      // bug, see https://github.com/flutter/flutter/issues/90697:
      scrollBehavior:
          const MaterialScrollBehavior().copyWith(scrollbars: !kIsWeb),
    );
  }
}

/// DevTools screen wrapper that is responsible for creating and providing the
/// screen's controller, as well as enabling offline support.
///
/// [C] corresponds to the type of the screen's controller, which is created by
/// [createController] and provided by [controllerProvider].
class DevToolsScreen<C> {
  const DevToolsScreen(
    this.screen, {
    this.createController,
    this.controller,
    this.supportsOffline = false,
  }) : assert(createController == null || controller == null);

  final Screen screen;

  /// Responsible for creating the controller for this screen, if non-null.
  ///
  /// The controller will then be provided via [controllerProvider], and
  /// widgets depending on this controller can access it by calling
  /// `Provider<C>.of(context)`.
  ///
  /// If [createController] and [controller] are both null, [screen] will be
  /// responsible for creating and maintaining its own controller.
  final C Function(DevToolsRouterDelegate)? createController;

  /// A provided controller for this screen, if non-null.
  ///
  /// The controller will then be provided via [controllerProvider], and
  /// widgets depending on this controller can access it by calling
  /// `Provider<C>.of(context)`.
  ///
  /// If [createController] and [controller] are both null, [screen] will be
  /// responsible for creating and maintaining its own controller.
  final C? controller;

  /// Returns true if a controller was provided for [screen]. If false,
  /// [screen] is responsible for creating and maintaining its own controller.
  bool get providesController => createController != null || controller != null;

  /// Whether this screen has implemented offline support.
  ///
  /// Defaults to false.
  final bool supportsOffline;

  Provider<C> controllerProvider(DevToolsRouterDelegate routerDelegate) {
    assert(
      (createController != null && controller == null) ||
          (createController == null && controller != null),
    );
    final controllerLocal = controller;
    if (controllerLocal != null) {
      return Provider<C>.value(value: controllerLocal);
    }
    return Provider<C>(create: (_) => createController!(routerDelegate));
  }
}

/// A [WidgetBuilder] that takes an additional map of URL query parameters and
/// args, as well a state not included in the URL.
typedef UrlParametersBuilder = Widget Function(
  BuildContext,
  String?,
  Map<String, String?>,
  DevToolsNavigationState?,
);

/// Displays the checked mode banner in the bottom end corner instead of the
/// top end corner.
///
/// This avoids issues with widgets in the appbar being hidden by the banner
/// in a web or desktop app.
class _AlternateCheckedModeBanner extends StatelessWidget {
  const _AlternateCheckedModeBanner({Key? key, required this.builder})
      : super(key: key);
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Banner(
      message: 'DEBUG',
      textDirection: TextDirection.ltr,
      location: BannerLocation.topStart,
      child: Builder(
        builder: builder,
      ),
    );
  }
}

/// Screens to initialize DevTools with.
///
/// If the screen depends on a provided controller, the provider should be
/// provided here.
///
/// Conditional screens can be added to this list, and they will automatically
/// be shown or hidden based on the [Screen.conditionalLibrary] provided.
List<DevToolsScreen> get defaultScreens {
  return devtoolsScreens ??= <DevToolsScreen>[
    DevToolsScreen<InspectorController>(
      InspectorScreen(),
      createController: (_) => InspectorController(
        inspectorTree: InspectorTreeController(
          gaId: InspectorScreenMetrics.summaryTreeGaId,
        ),
        detailsTree: InspectorTreeController(
          gaId: InspectorScreenMetrics.detailsTreeGaId,
        ),
        treeType: FlutterTreeType.widget,
      ),
    ),
    DevToolsScreen<PerformanceController>(
      PerformanceScreen(),
      createController: (_) => PerformanceController(),
      supportsOffline: true,
    ),
    DevToolsScreen<ProfilerScreenController>(
      ProfilerScreen(),
      createController: (_) => ProfilerScreenController(),
      supportsOffline: true,
    ),
    DevToolsScreen<MemoryController>(
      MemoryScreen(),
      createController: (_) => MemoryController(),
    ),
    DevToolsScreen<DebuggerController>(
      DebuggerScreen(),
      createController: (routerDelegate) => DebuggerController(
        routerDelegate: routerDelegate,
      ),
    ),
    DevToolsScreen<NetworkController>(
      NetworkScreen(),
      createController: (_) => NetworkController(),
    ),
    DevToolsScreen<LoggingController>(
      LoggingScreen(),
      createController: (_) => LoggingController(),
    ),
    DevToolsScreen<void>(
      ProviderScreen(),
      createController: (_) {},
    ),
    DevToolsScreen<AppSizeController>(
      AppSizeScreen(),
      createController: (_) => AppSizeController(),
    ),
    DevToolsScreen<VMDeveloperToolsController>(
      VMDeveloperToolsScreen(),
      createController: (_) => VMDeveloperToolsController(),
    ),
    // Show the sample DevTools screen.
    if (debugEnableSampleScreen && (kDebugMode || kProfileMode))
      DevToolsScreen<ExampleController>(
        const ExampleConditionalScreen(),
        createController: (_) => ExampleController(),
        supportsOffline: true,
      ),
  ];
}

@visibleForTesting
List<DevToolsScreen>? devtoolsScreens;
