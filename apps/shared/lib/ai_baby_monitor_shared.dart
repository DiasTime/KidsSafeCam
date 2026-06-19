/// Public API of the shared package consumed by camera_app and parent_app.
library ai_baby_monitor_shared;

// Domain entities
export 'src/domain/entities/app_notification.dart';
export 'src/domain/entities/app_user.dart';
export 'src/domain/entities/baby_event.dart';
export 'src/domain/entities/device.dart';

// Core
export 'src/core/constants.dart';
export 'src/core/router/go_router_refresh_stream.dart';
export 'src/core/theme.dart';

// Auth feature
export 'src/features/auth/data/repositories/firebase_auth_repository.dart';
export 'src/features/auth/domain/repositories/auth_repository.dart';
export 'src/features/auth/presentation/auth_providers.dart';
export 'src/features/auth/presentation/pages/login_page.dart';

// Devices feature
export 'src/features/devices/data/models/device_model.dart';
export 'src/features/devices/data/repositories/firestore_device_repository.dart';
export 'src/features/devices/domain/repositories/device_repository.dart';
export 'src/features/devices/presentation/device_providers.dart';

// Events feature (event history)
export 'src/features/events/data/models/event_model.dart';
export 'src/features/events/data/repositories/firestore_event_repository.dart';
export 'src/features/events/domain/repositories/event_repository.dart';
export 'src/features/events/presentation/event_providers.dart';

// Notifications feature (in-app history)
export 'src/features/notifications/data/models/notification_model.dart';
export 'src/features/notifications/data/repositories/firestore_notification_repository.dart';
export 'src/features/notifications/domain/repositories/notification_repository.dart';
export 'src/features/notifications/presentation/notification_providers.dart';

// Pairing feature
export 'src/features/pairing/data/repositories/functions_pairing_repository.dart';
export 'src/features/pairing/domain/repositories/pairing_repository.dart';
export 'src/features/pairing/presentation/pairing_providers.dart';

// Signaling feature (WebRTC)
export 'src/features/signaling/data/signaling_client.dart';
export 'src/features/signaling/domain/ice_config.dart';
export 'src/features/signaling/presentation/signaling_providers.dart';

// Streaming feature (WebRTC peer connection + media)
export 'src/features/streaming/data/webrtc_session.dart';
export 'src/features/streaming/presentation/streaming_providers.dart';
