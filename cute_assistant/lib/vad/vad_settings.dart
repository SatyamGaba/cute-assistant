import 'package:flutter/material.dart';

enum RecordingModel {
  legacy,
  v5,
}

class VadSettings {
  // Model type
  RecordingModel model;

  // Frame settings
  int frameSamples;
  int minSpeechFrames;
  int preSpeechPadFrames;
  int redemptionFrames;

  // Threshold settings
  double positiveSpeechThreshold;
  double negativeSpeechThreshold;

  // Behavior settings
  bool submitUserSpeechOnPause;

  VadSettings({
    this.model = RecordingModel.v5,
    this.frameSamples = 512,
    this.minSpeechFrames = 8,
    this.preSpeechPadFrames = 30,
    this.redemptionFrames = 24,
    this.positiveSpeechThreshold = 0.5,
    this.negativeSpeechThreshold = 0.35,
    this.submitUserSpeechOnPause = false,
  });

  // Clone the settings
  VadSettings copy() {
    return VadSettings(
      model: model,
      frameSamples: frameSamples,
      minSpeechFrames: minSpeechFrames,
      preSpeechPadFrames: preSpeechPadFrames,
      redemptionFrames: redemptionFrames,
      positiveSpeechThreshold: positiveSpeechThreshold,
      negativeSpeechThreshold: negativeSpeechThreshold,
      submitUserSpeechOnPause: submitUserSpeechOnPause,
    );
  }

  // Reset to defaults based on model type
  void resetToDefaults() {
    if (model == RecordingModel.legacy) {
      // Default v4 values
      frameSamples = 1536;
      minSpeechFrames = 3;
      preSpeechPadFrames = 10;
      redemptionFrames = 8;
      positiveSpeechThreshold = 0.5;
      negativeSpeechThreshold = 0.35;
    } else {
      // Default v5 values
      frameSamples = 512;
      minSpeechFrames = 8;
      preSpeechPadFrames = 30;
      redemptionFrames = 24;
      positiveSpeechThreshold = 0.5;
      negativeSpeechThreshold = 0.35;
    }
  }

  // Get the model string for the VAD library
  String get modelString => model == RecordingModel.legacy ? 'legacy' : 'v5';

  // Helper function to calculate time from frames
  String calculateTimeFromFrames(int frames) {
    // 16kHz = 16000 samples per second
    double seconds = (frames * frameSamples) / 16000;
    if (seconds < 1) {
      return '${(seconds * 1000).toStringAsFixed(0)} ms';
    } else {
      return '${seconds.toStringAsFixed(2)} s';
    }
  }

  // Calculate frame time
  String calculateFrameTime() {
    double milliseconds = (frameSamples / 16000) * 1000;
    return '${milliseconds.toStringAsFixed(0)} ms';
  }
}

class VadSettingsDialog extends StatefulWidget {
  final VadSettings settings;
  final Function(VadSettings) onSettingsChanged;

  const VadSettingsDialog({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<VadSettingsDialog> createState() => _VadSettingsDialogState();
}

class _VadSettingsDialogState extends State<VadSettingsDialog> {
  late VadSettings tempSettings;

  @override
  void initState() {
    super.initState();
    tempSettings = widget.settings.copy();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('VAD Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Model selection
            Row(
              children: [
                const Text('Model:'),
                const SizedBox(width: 8),
                DropdownButton<RecordingModel>(
                  value: tempSettings.model,
                  items: const [
                    DropdownMenuItem(
                        value: RecordingModel.legacy,
                        child: Text('v4 (Legacy)')),
                    DropdownMenuItem(
                        value: RecordingModel.v5, child: Text('v5')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        tempSettings.model = value;
                        tempSettings.resetToDefaults();
                      });
                    }
                  },
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      tempSettings.resetToDefaults();
                    });
                  },
                  child: const Text('Reset to Defaults'),
                ),
              ],
            ),
            const Divider(),

            // Frame Samples
            const Text('Frame Samples:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tempSettings.model == RecordingModel.legacy
                        ? '1536'
                        : '512',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            Text('1 frame = ${tempSettings.calculateFrameTime()} at 16kHz'),
            const SizedBox(height: 16),

            // Min Speech Frames
            const Text('Min Speech Frames:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: tempSettings.minSpeechFrames.toDouble(),
                    min: 1,
                    max: 500,
                    divisions: 499,
                    onChanged: (value) {
                      setState(() {
                        tempSettings.minSpeechFrames = value.toInt();
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                        text: tempSettings.minSpeechFrames.toString()),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null) {
                        setState(() {
                          tempSettings.minSpeechFrames = parsed;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            Text(
                '${tempSettings.calculateTimeFromFrames(tempSettings.minSpeechFrames)} of speech required'),
            const SizedBox(height: 16),

            // Pre Speech Pad Frames
            const Text('Pre Speech Pad Frames:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: tempSettings.preSpeechPadFrames.toDouble(),
                    min: 0,
                    max: 500,
                    divisions: 500,
                    onChanged: (value) {
                      setState(() {
                        tempSettings.preSpeechPadFrames = value.toInt();
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                        text: tempSettings.preSpeechPadFrames.toString()),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null) {
                        setState(() {
                          tempSettings.preSpeechPadFrames = parsed;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            Text(
                '${tempSettings.calculateTimeFromFrames(tempSettings.preSpeechPadFrames)} padding before speech'),
            const SizedBox(height: 16),

            // Redemption Frames
            const Text('Redemption Frames:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: tempSettings.redemptionFrames.toDouble(),
                    min: 0,
                    max: 500,
                    divisions: 50,
                    onChanged: (value) {
                      setState(() {
                        tempSettings.redemptionFrames = value.toInt();
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                        text: tempSettings.redemptionFrames.toString()),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null) {
                        setState(() {
                          tempSettings.redemptionFrames = parsed;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            Text(
                '${tempSettings.calculateTimeFromFrames(tempSettings.redemptionFrames)} before ending speech detection'),
            const SizedBox(height: 16),

            // Positive Speech Threshold
            const Text('Positive Speech Threshold:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: tempSettings.positiveSpeechThreshold,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (value) {
                      setState(() {
                        tempSettings.positiveSpeechThreshold = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    controller: TextEditingController(
                        text: tempSettings.positiveSpeechThreshold
                            .toStringAsFixed(2)),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null) {
                        setState(() {
                          tempSettings.positiveSpeechThreshold = parsed;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Negative Speech Threshold
            const Text('Negative Speech Threshold:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: tempSettings.negativeSpeechThreshold,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (value) {
                      setState(() {
                        tempSettings.negativeSpeechThreshold = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    controller: TextEditingController(
                        text: tempSettings.negativeSpeechThreshold
                            .toStringAsFixed(2)),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null) {
                        setState(() {
                          tempSettings.negativeSpeechThreshold = parsed;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Submit on Pause
            Row(
              children: [
                Checkbox(
                  value: tempSettings.submitUserSpeechOnPause,
                  onChanged: (value) {
                    setState(() {
                      tempSettings.submitUserSpeechOnPause = value ?? false;
                    });
                  },
                ),
                const Text('Submit User Speech On Pause'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Cancel
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Apply settings
            widget.onSettingsChanged(tempSettings);
            Navigator.of(context).pop(); // Close dialog
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}