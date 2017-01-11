//
//  wxs_fmdbHelper.h
//  wxs_fmdbManager
//
//  Created by macmini on 2016/10/25.
//  Copyright © 2016年 wxs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"
#import "wxs_fmdbModel.h"
#import "wxs_fmdbMigration.h"

#define fmdbHelper [wxs_fmdbHelper shareInstance]

@interface wxs_fmdbHelper : NSObject

@property (nonatomic, retain, readonly) FMDatabaseQueue *dbQueue;


/**
 fmdbHelper 单利

 @return 实例
 */
+ (wxs_fmdbHelper *)shareInstance;

/**
 返回当前db路劲

 @return 路径
 */
- (NSString *)dbPath;
/**
 异步执行sql(默认暴露在外的dbQueue为线程安全的)
 
 @param sql sql语句
 @return 返回结果
 */
- (BOOL)excuteSqlWithoutQueue:(NSString *)sql;






#pragma mark ----------拷贝本地数据库到沙盒中
/**
 拷贝本地数据库到沙盒中
 
 @param fileName     文件名(工程内db名称)
 @param dataBaseName 存储db名称
 */
- (void)copyLocalDatabaseIfNeededWithFileName:(NSString *)fileName dataBaseName:(NSString *)dataBaseName;






#pragma mark ----------切换数据库
/**
 切换数据库(仅支持通过LMJDBManager创建的数据库)
 
 @param dataBaseName 数据库名
 
 @return 是否成功
 */
- (BOOL)changeDBWithDataBaseName:(NSString *)dataBaseName;
/**
 切换数据库(仅支持通过LMJDBManager创建的数据库)
 
 @param dataBaseName 数据库名
 @param autoCreate   是否自动创建数据库
 
 @return 是否成功
 */
- (BOOL)changeDBWithDataBaseName:(NSString *)dataBaseName autoCreatTablesWithLMJDDBModel:(BOOL)autoCreate;
/**
 通过完整的地址切换数据库（支持其他方式创建的数据库）
 
 @param path 数据库地址
 
 @return 是否成功
 */
- (BOOL)changeDBWithDBPath:(NSString *)path;


#pragma mark ----------迁移数据库

- (BOOL)migrateDatabaseToVersion:(uint64_t)version progress:(void (^)(NSProgress *progress))progressBlock error:(NSError **)error;

@end
