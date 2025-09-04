import 'package:event_bus/event_bus.dart';

// 1. 创建全局的eventBus实例
EventBus eventBus = EventBus();

//2. 创建一个事件类,通知登录页跳转
class LogoutEvent {
  LogoutEvent();
}

//3. 创建头像更新事件类
class AvatarUpdatedEvent {
  final String avatarPath;

  AvatarUpdatedEvent(this.avatarPath);
}
