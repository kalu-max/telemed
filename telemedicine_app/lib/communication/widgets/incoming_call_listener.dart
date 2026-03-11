import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/call_model.dart';
import '../providers/communication_providers.dart';
import 'call_widgets.dart';

class IncomingCallListener extends StatefulWidget {
  final Widget child;

  const IncomingCallListener({super.key, required this.child});

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  String? _dialogCallId;
  bool _dialogVisible = false;

  @override
  Widget build(BuildContext context) {
    final currentCall = context.watch<VideoCallingProvider>().currentCall;
    final isIncomingRinging =
        currentCall != null &&
        currentCall.direction == CallDirection.incoming &&
        currentCall.status == CallStatus.ringing;

    if (isIncomingRinging &&
        !_dialogVisible &&
        _dialogCallId != currentCall.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIncomingCallDialog(currentCall);
      });
    }

    if (!isIncomingRinging && _dialogVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _dismissIncomingDialog();
      });
    }

    return widget.child;
  }

  Future<void> _showIncomingCallDialog(CallSession call) async {
    if (!mounted || _dialogVisible) {
      return;
    }

    _dialogVisible = true;
    _dialogCallId = call.id;

    final action = await showDialog<_IncomingCallAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Incoming Video Call'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.teal[700],
                child: Text(
                  call.callerName.isNotEmpty
                      ? call.callerName[0].toUpperCase()
                      : 'D',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                call.callerName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Do you want to join the consultation now?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_IncomingCallAction.decline),
              child: const Text('Decline'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_IncomingCallAction.accept),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );

    _dialogVisible = false;
    _dialogCallId = null;

    if (!mounted || action == null) {
      return;
    }

    final provider = context.read<VideoCallingProvider>();
    final latestCall = provider.currentCall;
    if (latestCall == null || latestCall.id != call.id) {
      return;
    }

    try {
      if (action == _IncomingCallAction.decline) {
        await provider.rejectCall();
        return;
      }

      await provider.acceptCall();
      if (!mounted) {
        return;
      }

      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            recipientId: latestCall.callerId,
            recipientName: latestCall.callerName,
            conversationId: latestCall.id,
            isIncoming: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to join call: $e')));
    }
  }

  Future<void> _dismissIncomingDialog() async {
    if (!mounted || !_dialogVisible) {
      return;
    }

    await Navigator.of(context, rootNavigator: true).maybePop();
  }
}

enum _IncomingCallAction { accept, decline }
