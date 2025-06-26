lib/
├── main.dart
├── app/
│   ├── app.dart              # App root with routing
│   └── router.dart           # Named routes config
├── features/
│   ├── user/
│   │   ├── view/user_page.dart
│   │   ├── bloc/user_bloc.dart
│   │   ├── widgets/
│   │   │   └── camera_view.dart
│   │   └── services/
│   │       └── camera_service.dart
│   ├── navigator/
│   │   ├── view/navigator_page.dart
│   │   ├── bloc/navigator_bloc.dart
│   │   ├── widgets/
│   │   │   └── drawing_canvas.dart
│   │   └── services/
│   │       └── drawing_service.dart
│   └── shared/
│       ├── services/
│       │   └── webrtc_service.dart
│       ├── models/
│       │   └── shared_models.dart
│       └── widgets/
│           └── shared_ui.dart
├── utils/
│   ├── constants.dart
│   └── helpers.dart
└── bootstrap.dart           # App bootstrap logic
