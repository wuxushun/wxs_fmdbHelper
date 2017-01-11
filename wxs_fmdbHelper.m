//
//  wxs_fmdbHelper.m
//  wxs_fmdbManager
//
//  Created by macmini on 2016/10/25.
//  Copyright © 2016年 wxs. All rights reserved.
//

#import <objc/runtime.h>

#import "wxs_fmdbHelper.h"

@interface wxs_fmdbHelper ()

@property (nonatomic, retain) FMDatabaseQueue *dbQueue;
@property (nonatomic, retain) FMDatabase *db;
@property (nonatomic, copy) NSString *defaultDBPath;

@end

@implementation wxs_fmdbHelper

static wxs_fmdbHelper *_instance = nil;

+ (instancetype)shareInstance
{
    static dispatch_once_t onceToken ;
    dispatch_once(&onceToken, ^{
        _instance = [[super allocWithZone:NULL] init] ;
    }) ;
    
    return _instance;
}

- (NSString *)dbPathWithDataBaseName:(NSString *)dataBaseName
{
    NSString *docsdir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSFileManager *filemanage = [NSFileManager defaultManager];
    docsdir = [docsdir stringByAppendingPathComponent:@"wxs_db"];
    BOOL isDir;
    BOOL exit =[filemanage fileExistsAtPath:docsdir isDirectory:&isDir];
    if (!exit || !isDir) {
        [filemanage createDirectoryAtPath:docsdir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *dbpath = [docsdir stringByAppendingPathComponent:[NSString stringWithFormat:@"wxs_db_%@.sqlite",dataBaseName]];
    return dbpath;
}

- (NSString *)dbPath
{
    return !fmdbHelper.defaultDBPath?[self dbPathWithDataBaseName:nil]:fmdbHelper.defaultDBPath;
}

- (FMDatabaseQueue *)dbQueue
{
    if (_dbQueue == nil) {
        _dbQueue = [[FMDatabaseQueue alloc] initWithPath:[self dbPath]];
    }
    return _dbQueue;
}

-(FMDatabase *)db
{
    if (_db == nil) {
        _db = [[FMDatabase alloc] initWithPath:[self dbPath]];
    }
    return _db;
}

- (BOOL)changeDBWithDBPath:(NSString *)path
{
    if (path == nil) {
        return NO;
    }
    
    fmdbHelper.dbQueue = nil;
    fmdbHelper.dbQueue = [[FMDatabaseQueue alloc] initWithPath:path];
    fmdbHelper.db = nil;
    fmdbHelper.db = [[FMDatabase alloc] initWithPath:path];
    fmdbHelper.defaultDBPath = path;
    
    return YES;
}

- (BOOL)changeDBWithDataBaseName:(NSString *)dataBaseName autoCreatTablesWithLMJDDBModel:(BOOL)autoCreate
{
    [self changeDBWithDBPath:[fmdbHelper dbPathWithDataBaseName:dataBaseName]];
    
    if (autoCreate) {
        int numClasses;
        Class *classes = NULL;
        numClasses = objc_getClassList(NULL,0);
        
        if (numClasses >0 )
        {
            classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
            numClasses = objc_getClassList(classes, numClasses);
            for (int i = 0; i < numClasses; i++) {
                if (class_getSuperclass(classes[i]) == [wxs_fmdbModel class]){
                    id class = classes[i];
                    [class performSelector:@selector(createTable) withObject:nil];
                }
            }
            free(classes);
        }
    }
    
    return YES;
}
- (BOOL)changeDBWithDataBaseName:(NSString *)dataBaseName
{
    return [self changeDBWithDataBaseName:dataBaseName autoCreatTablesWithLMJDDBModel:NO];
}

- (void)copyLocalDatabaseIfNeededWithFileName:(NSString *)fileName dataBaseName:(NSString *)dataBaseName
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError * error = nil;
    NSArray * path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * docsdir = [path lastObject];
    docsdir = [docsdir stringByAppendingPathComponent:@"wxs_db"];
    NSString * dbPath = [docsdir stringByAppendingPathComponent:[NSString stringWithFormat:@"wxs_db_%@.sqlite",dataBaseName]];
    BOOL isExist = [fileManager fileExistsAtPath:dbPath];
    
    if(!isExist) {
        NSString *defaultDBPath = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
        if (!defaultDBPath || [defaultDBPath isEqualToString:@""]){
            NSLog(@"拷贝数据库失败，路径错误");
            return;
        }
        
        BOOL isSucced = [fileManager copyItemAtPath:defaultDBPath toPath:dbPath error:&error];
        if (!isSucced){
            NSAssert1(0, @"Failed to create writable database file with message '%@'.", [error localizedDescription]);
            return;
        }
    }
    fmdbHelper.defaultDBPath = dbPath;
}

+ (id)allocWithZone:(struct _NSZone *)zone
{
    return fmdbHelper;
}

- (id)copyWithZone:(struct _NSZone *)zone
{
    return fmdbHelper;
}


- (BOOL)excuteSqlWithoutQueue:(NSString *)sql
{
    [self.db open];
    BOOL executedFinish = [self.db executeUpdate:sql];
    [self.db close];
    return executedFinish;
}






#pragma mark ----------迁移数据库

- (BOOL)migrateDatabaseToVersion:(uint64_t)version progress:(void (^)(NSProgress *progress))progressBlock error:(NSError **)error
{
    wxs_fmdbMigration * manager = [wxs_fmdbMigration managerWithDatabase:self.db migrationsBundle:[NSBundle mainBundle]];
    
    BOOL resultState=NO;
    
    if (!manager.hasMigrationsTable) {
        resultState=[manager createMigrationsTable:error];
        if (!resultState) {
            return false;
        }
    }
    
    resultState = [manager migrateDatabaseToVersion:version progress:progressBlock error:error];
    return resultState;
}


#if ! __has_feature(objc_arc)
- (id)autorelease
{
    return _instance;
}

- (NSUInteger)retainCount
{
    return 1;
}
#endif

@end
