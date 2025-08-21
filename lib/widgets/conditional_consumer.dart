import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/build_config.dart';
import '../services/sync_service.dart';
import '../services/server_service.dart';

/// Widget ottimizzato che mostra Consumer solo se il servizio è disponibile
/// per la modalità build corrente
class ConditionalSyncConsumer extends StatelessWidget {
  final Widget Function(BuildContext context, SyncService syncService, Widget? child) builder;
  final Widget fallback;
  final Widget? child;

  const ConditionalSyncConsumer({
    super.key,
    required this.builder,
    required this.fallback,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!BuildConfig.shouldInitializeSyncService) {
      return fallback;
    }

    try {
      return Consumer<SyncService>(
        builder: builder,
        child: child,
      );
    } catch (e) {
      // Fallback se il service non è disponibile
      return fallback;
    }
  }
}

/// Widget ottimizzato che mostra Consumer solo se il servizio è disponibile
/// per la modalità build corrente
class ConditionalServerConsumer extends StatelessWidget {
  final Widget Function(BuildContext context, ServerService serverService, Widget? child) builder;
  final Widget fallback;
  final Widget? child;

  const ConditionalServerConsumer({
    super.key,
    required this.builder,
    required this.fallback,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!BuildConfig.shouldInitializeServerService) {
      return fallback;
    }

    try {
      return Consumer<ServerService>(
        builder: builder,
        child: child,
      );
    } catch (e) {
      // Fallback se il service non è disponibile
      return fallback;
    }
  }
}

/// Widget che mostra contenuto condizionale basato su build mode
class BuildModeConditional extends StatelessWidget {
  final Widget? baseContent;
  final Widget? proClientContent;
  final Widget? proServerContent;
  final Widget? proContent; // Per entrambe le modalità PRO
  final Widget? fallback;

  const BuildModeConditional({
    super.key,
    this.baseContent,
    this.proClientContent,
    this.proServerContent,
    this.proContent,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    switch (BuildConfig.appMode) {
      case AppMode.base:
        return baseContent ?? proContent ?? fallback ?? const SizedBox.shrink();
      case AppMode.proClient:
        return proClientContent ?? proContent ?? fallback ?? const SizedBox.shrink();
      case AppMode.proServer:
        return proServerContent ?? proContent ?? fallback ?? const SizedBox.shrink();
    }
  }
}

/// Widget per indicatori di stato build-mode aware
class BuildModeStatusIndicator extends StatelessWidget {
  final bool showConnectionStatus;
  final bool showSyncStatus;
  
  const BuildModeStatusIndicator({
    super.key,
    this.showConnectionStatus = true,
    this.showSyncStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!BuildConfig.showConnectionStatus && !BuildConfig.showSyncStatus) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stato connessione (solo per PRO modes)
        if (showConnectionStatus && BuildConfig.showConnectionStatus)
          ConditionalSyncConsumer(
            builder: (context, syncService, child) => Icon(
              syncService.isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: syncService.isConnected ? Colors.green : Colors.red,
              size: 16,
            ),
            fallback: const SizedBox.shrink(),
          ),
        
        const SizedBox(width: 4),
        
        // Stato sync (solo per PRO CLIENT)
        if (showSyncStatus && BuildConfig.showSyncStatus)
          ConditionalSyncConsumer(
            builder: (context, syncService, child) => Icon(
              syncService.isConnected ? Icons.sync : Icons.sync_disabled,
              color: syncService.isConnected ? Colors.blue : Colors.grey,
              size: 16,
            ),
            fallback: const SizedBox.shrink(),
          ),
      ],
    );
  }
}
