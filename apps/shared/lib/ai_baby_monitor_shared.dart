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
