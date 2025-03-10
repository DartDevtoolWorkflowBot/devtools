// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/primitives/simple_items.dart';
import '../../../../shared/split.dart';
import '../../../../shared/theme.dart';
import '../../shared/widgets/shared_memory_widgets.dart';
import 'class_table.dart';
import 'tracing_pane_controller.dart';
import 'tracing_tree.dart';

class TracingPane extends StatefulWidget {
  const TracingPane({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final TracingPaneController controller;

  @override
  State<TracingPane> createState() => TracingPaneState();
}

class TracingPaneState extends State<TracingPane> {
  @override
  void initState() {
    super.initState();

    unawaited(widget.controller.initialize());
  }

  @override
  Widget build(BuildContext context) {
    final isProfileMode =
        serviceManager.connectedApp?.isProfileBuildNow ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TracingControls(
          isProfileMode: isProfileMode,
          controller: widget.controller,
        ),
        Expanded(
          child: isProfileMode
              ? OutlineDecoration.onlyTop(
                  child: const Center(
                    child: Text(
                      'Allocation tracing is temporary disabled in profile mode.\n'
                      'Run the application in debug mode to trace allocations.',
                    ),
                  ),
                )
              : OutlineDecoration.onlyTop(
                  child: Split(
                    axis: Axis.horizontal,
                    initialFractions: const [0.25, 0.75],
                    children: [
                      OutlineDecoration.onlyRight(
                        child: AllocationTracingTable(
                          controller: widget.controller,
                        ),
                      ),
                      OutlineDecoration.onlyLeft(
                        child: AllocationTracingTree(
                          controller: widget.controller,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _TracingControls extends StatelessWidget {
  const _TracingControls({
    required this.isProfileMode,
    required this.controller,
  });

  final bool isProfileMode;

  final TracingPaneController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(denseSpacing),
      child: Row(
        children: [
          RefreshButton(
            tooltip: 'Request the set of updated allocation traces',
            gaScreen: gac.memory,
            gaSelection: gac.MemoryEvent.tracingRefresh,
            onPressed: isProfileMode ? null : controller.refresh,
          ),
          const SizedBox(width: denseSpacing),
          ClearButton(
            tooltip: 'Clear the set of previously collected traces',
            gaScreen: gac.memory,
            gaSelection: gac.MemoryEvent.tracingClear,
            onPressed: isProfileMode ? null : controller.clear,
          ),
          const SizedBox(width: denseSpacing),
          const _ProfileHelpLink(),
        ],
      ),
    );
  }
}

class _ProfileHelpLink extends StatelessWidget {
  const _ProfileHelpLink({Key? key}) : super(key: key);

  static const _documentationTopic = gac.MemoryEvent.tracingHelp;

  @override
  Widget build(BuildContext context) {
    return HelpButtonWithDialog(
      gaScreen: gac.memory,
      gaSelection: gac.topicDocumentationButton(_documentationTopic),
      dialogTitle: 'Memory Allocation Tracing Help',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'The allocation tracing tab allows for toggling allocation\n'
            'tracing for specific types, which records the locations of\n'
            'allocations of instances of traced types within the\n'
            'currently selected isolate.\n'
            '\n'
            'Allocation sites of traced types can be viewed by refreshing\n'
            'the tracing profile before selecting the traced type from the\n'
            'list, displaying a condensed view of locations where objects\n'
            'were allocated.',
          ),
          const SizedBox(height: denseSpacing),
          const ClassTypeLegend(),
          MoreInfoLink(
            url: DocLinks.trace.value,
            gaScreenName: gac.memory,
            gaSelectedItemDescription:
                gac.topicDocumentationLink(_documentationTopic),
          ),
        ],
      ),
    );
  }
}
