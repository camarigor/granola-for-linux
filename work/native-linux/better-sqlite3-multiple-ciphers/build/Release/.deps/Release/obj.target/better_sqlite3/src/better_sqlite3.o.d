cmd_Release/obj.target/better_sqlite3/src/better_sqlite3.o := g++ -o Release/obj.target/better_sqlite3/src/better_sqlite3.o ../src/better_sqlite3.cpp '-DNODE_GYP_MODULE_NAME=better_sqlite3' '-DUSING_UV_SHARED=1' '-DUSING_V8_SHARED=1' '-DV8_DEPRECATION_WARNINGS=1' '-D_GLIBCXX_USE_CXX11_ABI=1' '-D_FILE_OFFSET_BITS=64' '-DELECTRON_ENSURE_CONFIG_GYPI' '-D_LARGEFILE_SOURCE' '-DUSING_ELECTRON_CONFIG_GYPI' '-DV8_COMPRESS_POINTERS' '-DV8_COMPRESS_POINTERS_IN_MULTIPLE_CAGES' '-DV8_31BIT_SMIS_ON_64BIT_ARCH' '-DV8_ENABLE_SANDBOX' '-DV8_EXTERNAL_CODE_SPACE' '-D__STDC_FORMAT_MACROS' '-DOPENSSL_NO_PINSHARED' '-DOPENSSL_THREADS' '-DOPENSSL_NO_ASM' '-DBUILDING_NODE_EXTENSION' '-DNDEBUG' -I/root/.cache/node-gyp/42.7.0/include/node -I/root/.cache/node-gyp/42.7.0/src -I/root/.cache/node-gyp/42.7.0/deps/openssl/config -I/root/.cache/node-gyp/42.7.0/deps/openssl/openssl/include -I/root/.cache/node-gyp/42.7.0/deps/uv/include -I/root/.cache/node-gyp/42.7.0/deps/zlib -I/root/.cache/node-gyp/42.7.0/deps/v8/include -I./Release/obj/gen/sqlite3  -fPIC -pthread -Wall -Wextra -Wno-unused-parameter -m64 -O3 -O3 -fno-omit-frame-pointer -fno-rtti -fno-exceptions -fno-strict-aliasing -std=gnu++20 -std=c++20 -MMD -MF ./Release/.deps/Release/obj.target/better_sqlite3/src/better_sqlite3.o.d.raw   -c
Release/obj.target/better_sqlite3/src/better_sqlite3.o: \
 ../src/better_sqlite3.cpp Release/obj/gen/sqlite3/sqlite3.h \
 /root/.cache/node-gyp/42.7.0/include/node/node.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/common.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8config.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-array-buffer.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-local-handle.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-handle-base.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-internal.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8config.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-memory-span.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-object.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/garbage-collected.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/api-constants.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/platform.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/source-location.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-source-location.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-platform.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-source-location.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/trace-trait.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/type-traits.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/name-provider.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-maybe.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/conditional-stack-allocated.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/macros.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/compiler-specific.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-persistent-handle.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-weak-callback-info.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-primitive.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-data.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-value.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-sandbox.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-traced-handle.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-platform.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-container.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-context.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-snapshot.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-isolate.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-callbacks.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-promise.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-debug.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-script.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-message.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-embedder-heap.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-exception.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-function-callback.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-microtask.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-statistics.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-unwinder.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-embedder-state-scope.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-date.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-extension.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-external.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-function.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-template.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-initialization.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-json.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-locker.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-microtask-queue.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-primitive-object.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-proxy.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-regexp.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-typed-array.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-value-serializer.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-version.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-wasm.h \
 /root/.cache/node-gyp/42.7.0/include/node/v8-cppgc.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/custom-space.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/heap-statistics.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/visitor.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/custom-space.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/garbage-collected.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/logging.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/member-storage.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/caged-heap.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/base-page-handle.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/heap-handle.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/sentinel-pointer.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/pointer-policies.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/write-barrier.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/heap-state.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/atomic-entry-flag.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/liveness-broker.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/heap.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/common.h \
 /root/.cache/node-gyp/42.7.0/include/node/cppgc/member.h \
 /root/.cache/node-gyp/42.7.0/include/node/node_version.h \
 /root/.cache/node-gyp/42.7.0/include/node/node_api.h \
 /root/.cache/node-gyp/42.7.0/include/node/js_native_api.h \
 /root/.cache/node-gyp/42.7.0/include/node/js_native_api_types.h \
 /root/.cache/node-gyp/42.7.0/include/node/node_api_types.h \
 /root/.cache/node-gyp/42.7.0/include/node/node_object_wrap.h \
 /root/.cache/node-gyp/42.7.0/include/node/node_buffer.h \
 /root/.cache/node-gyp/42.7.0/include/node/node.h ../src/util/macros.cpp \
 ../src/util/helpers.cpp ../src/util/constants.cpp \
 ../src/util/bind-map.cpp ../src/util/data-converter.cpp \
 ../src/util/data.cpp ../src/util/row-builder.cpp \
 ../src/objects/backup.hpp ../src/objects/statement.hpp \
 ../src/objects/database.hpp ../src/addon.cpp \
 ../src/objects/statement-iterator.hpp ../src/util/query-macros.cpp \
 ../src/util/custom-function.cpp ../src/util/custom-aggregate.cpp \
 ../src/util/custom-table.cpp ../src/util/binder.cpp \
 ../src/objects/backup.cpp ../src/objects/statement.cpp \
 ../src/objects/database.cpp ../src/objects/statement-iterator.cpp
../src/better_sqlite3.cpp:
Release/obj/gen/sqlite3/sqlite3.h:
/root/.cache/node-gyp/42.7.0/include/node/node.h:
/root/.cache/node-gyp/42.7.0/include/node/v8.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/common.h:
/root/.cache/node-gyp/42.7.0/include/node/v8config.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-array-buffer.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-local-handle.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-handle-base.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-internal.h:
/root/.cache/node-gyp/42.7.0/include/node/v8config.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-memory-span.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-object.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/garbage-collected.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/api-constants.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/platform.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/source-location.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-source-location.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-platform.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-source-location.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/trace-trait.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/type-traits.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/name-provider.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-maybe.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/conditional-stack-allocated.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/macros.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/compiler-specific.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-persistent-handle.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-weak-callback-info.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-primitive.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-data.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-value.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-sandbox.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-traced-handle.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-platform.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-container.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-context.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-snapshot.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-isolate.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-callbacks.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-promise.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-debug.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-script.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-message.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-embedder-heap.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-exception.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-function-callback.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-microtask.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-statistics.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-unwinder.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-embedder-state-scope.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-date.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-extension.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-external.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-function.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-template.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-initialization.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-json.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-locker.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-microtask-queue.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-primitive-object.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-proxy.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-regexp.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-typed-array.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-value-serializer.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-version.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-wasm.h:
/root/.cache/node-gyp/42.7.0/include/node/v8-cppgc.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/custom-space.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/heap-statistics.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/visitor.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/custom-space.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/garbage-collected.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/logging.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/member-storage.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/caged-heap.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/base-page-handle.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/heap-handle.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/sentinel-pointer.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/pointer-policies.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/write-barrier.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/heap-state.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/internal/atomic-entry-flag.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/liveness-broker.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/heap.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/common.h:
/root/.cache/node-gyp/42.7.0/include/node/cppgc/member.h:
/root/.cache/node-gyp/42.7.0/include/node/node_version.h:
/root/.cache/node-gyp/42.7.0/include/node/node_api.h:
/root/.cache/node-gyp/42.7.0/include/node/js_native_api.h:
/root/.cache/node-gyp/42.7.0/include/node/js_native_api_types.h:
/root/.cache/node-gyp/42.7.0/include/node/node_api_types.h:
/root/.cache/node-gyp/42.7.0/include/node/node_object_wrap.h:
/root/.cache/node-gyp/42.7.0/include/node/node_buffer.h:
/root/.cache/node-gyp/42.7.0/include/node/node.h:
../src/util/macros.cpp:
../src/util/helpers.cpp:
../src/util/constants.cpp:
../src/util/bind-map.cpp:
../src/util/data-converter.cpp:
../src/util/data.cpp:
../src/util/row-builder.cpp:
../src/objects/backup.hpp:
../src/objects/statement.hpp:
../src/objects/database.hpp:
../src/addon.cpp:
../src/objects/statement-iterator.hpp:
../src/util/query-macros.cpp:
../src/util/custom-function.cpp:
../src/util/custom-aggregate.cpp:
../src/util/custom-table.cpp:
../src/util/binder.cpp:
../src/objects/backup.cpp:
../src/objects/statement.cpp:
../src/objects/database.cpp:
../src/objects/statement-iterator.cpp:
