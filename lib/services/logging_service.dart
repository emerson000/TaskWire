import 'package:talker/talker.dart';

class LoggingService {
  static final Talker _talker = Talker();
  
  static Talker get instance => _talker;
  
  static void debug(String message) {
    _talker.debug(message);
  }
  
  static void info(String message) {
    _talker.info(message);
  }
  
  static void warning(String message) {
    _talker.warning(message);
  }
  
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _talker.error(message, error, stackTrace);
  }
  
  static void critical(String message, [dynamic error, StackTrace? stackTrace]) {
    _talker.critical(message, error, stackTrace);
  }
} 