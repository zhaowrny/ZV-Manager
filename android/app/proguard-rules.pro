# Flutter 的 release 构建默认开启 R8 混淆（本文件存在时会自动加入 proguardFiles）。
#
# shared_preferences 等插件用 JNIGen 生成 Dart 绑定，Dart 侧按「类名 + 方法名 +
# 描述符」字符串查找 Java 方法，描述符里含 kotlin.coroutines.Continuation 等
# 类型名。R8 把它们改名（实测 Continuation -> vd）后运行期就抛 NoSuchMethodError，
# SharedPreferences 整体失效：壁纸保存不上，主题、服务器列表也无法持久化。
# debug 不开 R8，所以只有 release 出问题。

# Kotlin 标准库类名会出现在 JNIGen 的方法描述符里
-keepnames class kotlin.**

# suspend 方法的末端参数，名字写死在 Dart 绑定里，连成员一起保留最稳妥
-keep class kotlin.coroutines.Continuation { *; }

# Dart 侧按全限定类名查找插件类（如 SharedPreferencesApiRegistrar）
-keepnames class io.flutter.plugins.** { *; }
