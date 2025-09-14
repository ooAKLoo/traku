# 数据库架构重构说明

## 重构目标

将原有的单体 `DatabaseManager` 重构为**Repository模式 + 协议驱动**的架构，提高代码的可维护性、可扩展性和可测试性。

## 架构设计

### 整体架构图

```
┌─────────────────────────┐
│     DatabaseManager     │  ← 统一入口，路由请求
└────────────┬────────────┘
             │
    ┌────────┴────────┐
    │   Repository    │  ← 协议定义CRUD接口
    │    Protocol     │
    └────────┬────────┘
             │
    ┌────────┴────────────────┐
    │                          │
┌───▼──────────┐    ┌─────────▼────────┐
│ Recording    │    │  Inspiration     │
│ Repository   │    │   Repository     │
└───┬──────────┘    └─────────┬────────┘
    │                          │
    └──────────┬───────────────┘
               │
        ┌──────▼──────┐
        │ SQLiteCore  │  ← 底层SQL执行
        └─────────────┘
```

### 核心组件

#### 1. 协议层 (`DatabaseProtocols.swift`)
- `DatabaseModel`: 定义数据模型的标准接口
- `Repository`: 定义CRUD操作的标准接口
- `SQLiteOperations`: 定义SQLite操作的标准接口
- `FilterCriteria`: 定义查询条件
- `DatabaseError`: 统一错误类型

#### 2. 核心数据库操作 (`SQLiteCore.swift`)
- 封装所有SQLite底层操作
- 提供连接管理、事务支持、异步操作
- 统一错误处理和资源管理

#### 3. 数据模型层
- `AudioRecording`: 录音数据模型（支持 `DatabaseModel` + `Codable`）
- `InspirationData`: 灵感数据模型（支持 `DatabaseModel` + `Codable`）
- `EmbeddingData`: 向量数据模型（支持 `DatabaseModel` + `Codable`）

#### 4. Repository 实现层
- `RecordingRepository`: 录音数据仓库
- `InspirationRepository`: 灵感数据仓库
- `EmbeddingRepository`: 向量数据仓库

#### 5. 管理层
- `DatabaseManager`: 统一路由和协调
- `DatabaseDebugger`: 调试和诊断工具

## 重构优势

### 1. 单一职责原则
每个Repository只负责一个表的操作，职责明确。

### 2. 开闭原则
添加新表只需实现Repository协议，无需修改现有代码。

### 3. 依赖倒置
高层模块依赖于抽象（协议），而不是具体实现。

### 4. 类型安全
使用泛型和协议确保编译时类型安全。

### 5. 可测试性
可以轻松Mock Repository进行单元测试。

### 6. 异步支持
全面支持 `async/await`，提供更好的性能。

## 主要文件说明

### 核心文件
1. `DatabaseProtocols.swift` - 协议定义
2. `SQLiteCore.swift` - SQLite核心操作
3. `DatabaseManager.swift` - 统一管理器
4. `DatabaseDebugger.swift` - 调试工具

### Repository层
1. `RecordingRepository.swift` - 录音数据操作
2. `InspirationRepository.swift` - 灵感数据操作
3. `EmbeddingRepository.swift` - 向量数据操作

### 数据模型（已更新）
1. `AudioRecording.swift` - 录音模型（新增DatabaseModel支持）
2. `InspirationData.swift` - 灵感模型（新增字段和协议支持）
3. `EmbeddingData.swift` - 向量模型（新创建）

### 备份文件
1. `DatabaseManager_Backup.swift` - 原始DatabaseManager备份

## API兼容性

重构后的 `DatabaseManager` 保持了与原有代码的API兼容性：

```swift
// 录音操作
DatabaseManager.shared.saveRecording(_:)
DatabaseManager.shared.loadRecordings()
DatabaseManager.shared.updateRecording(_:)
DatabaseManager.shared.deleteRecording(id:)

// 灵感操作
DatabaseManager.shared.saveInspiration(...)
DatabaseManager.shared.loadInspirations()

// 向量操作
DatabaseManager.shared.saveEmbeddings(_:)
DatabaseManager.shared.getEmbeddings(for:)

// 工具方法
DatabaseManager.shared.exportDatabaseDebugInfo()
DatabaseManager.shared.printDebugInfo() // 新增
```

## 使用示例

### 基本CRUD操作
```swift
// 通过Repository直接操作
let recording = AudioRecording(...)
let success = try await recordingRepository.create(recording)

// 通过DatabaseManager操作（推荐）
let success = DatabaseManager.shared.saveRecording(recording)
```

### 调试功能
```swift
// 打印调试信息
DatabaseManager.shared.printDebugInfo()

// 导出详细报告
let fileName = await DatabaseManager.shared.debugger.exportDebugReport()
```

### 高级查询
```swift
// 使用FilterCriteria进行复杂查询
let filter = FilterCriteria(
    limit: 10,
    orderBy: "created_at",
    ascending: false,
    whereClause: "title LIKE ?",
    parameters: ["%关键词%"]
)
let recordings = try await recordingRepository.list(filter: filter)
```

## 性能优化

1. **连接池管理**: SQLiteCore管理数据库连接生命周期
2. **批量操作**: EmbeddingRepository支持批量插入
3. **事务支持**: 复杂操作使用事务保证原子性
4. **异步操作**: 全面支持async/await，避免阻塞UI线程
5. **索引优化**: 在关键字段上创建索引

## 测试建议

1. **单元测试**: Mock Repository接口进行业务逻辑测试
2. **集成测试**: 使用内存数据库测试完整流程
3. **性能测试**: 测试大数据量下的操作性能
4. **错误处理测试**: 测试各种错误场景的处理

## 未来扩展

1. **添加新表**: 创建新的Model和Repository实现
2. **支持其他数据库**: 实现新的Core类（如CoreData、Realm）
3. **缓存层**: 在Repository层添加缓存机制
4. **数据同步**: 添加云同步支持
5. **数据迁移**: 支持数据库版本迁移

## 注意事项

1. **向后兼容**: 现有代码无需修改，API保持兼容
2. **渐进迁移**: 可以逐步将现有代码迁移到新架构
3. **错误处理**: 统一的错误处理机制，便于调试
4. **资源管理**: 自动管理数据库连接和资源释放

这次重构为项目奠定了坚实的数据访问基础，为未来的功能扩展提供了良好的架构支撑。