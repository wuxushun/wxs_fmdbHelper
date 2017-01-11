//
//  wxs_fmdbModel.m
//  wxs_fmdbManager
//
//  Created by macmini on 2016/10/25.
//  Copyright © 2016年 wxs. All rights reserved.
//

#import "wxs_fmdbModel.h"
#import "wxs_fmdbHelper.h"

#import <objc/runtime.h>

@interface wxs_fmdbModel ()

@property (strong, nonatomic) NSString *pk;

@end

@implementation wxs_fmdbModel

#pragma mark - override method
+ (void)initialize
{
    if (self != [wxs_fmdbModel self]) {
        [self createTable];
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSDictionary *dic = [self.class getAllProperties];
        _columeNames = [[NSMutableArray alloc] initWithArray:[dic objectForKey:@"name"]];
        _columeTypes = [[NSMutableArray alloc] initWithArray:[dic objectForKey:@"type"]];
        self.pk = @"-1";
    }
    
    return self;
}

- (NSString *)getPK
{
    return self.pk;
}

#pragma mark - base method
/**
 *  获取该类的所有属性
 */
+ (NSDictionary *)getPropertys
{
    NSMutableArray *proNames = [NSMutableArray array];
    NSMutableArray *proTypes = [NSMutableArray array];
    NSArray *theTransients = [[self class] ignoreKeys];
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        //获取属性名
        NSString *propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        if ([theTransients containsObject:propertyName]) {
            continue;
        }
        [proNames addObject:propertyName];
        //获取属性类型等参数
        NSString *propertyType = [NSString stringWithCString: property_getAttributes(property) encoding:NSUTF8StringEncoding];
        /*
         各种符号对应类型，部分类型在新版SDK中有所变化，如long 和long long
         c char         C unsigned char
         i int          I unsigned int
         l long         L unsigned long
         s short        S unsigned short
         d double       D unsigned double
         f float        F unsigned float
         q long long    Q unsigned long long
         B BOOL
         @ 对象类型 //指针 对象类型 如NSString 是@“NSString”
         
         
         64位下long 和long long 都是Tq
         SQLite 默认支持五种数据类型TEXT、INTEGER、REAL、BLOB、NULL
         因为在项目中用的类型不多，故只考虑了少数类型
         */
        if ([propertyType hasPrefix:@"T@\"NSString\""]) {
            [proTypes addObject:SQLTEXT];
        } else if ([propertyType hasPrefix:@"T@\"NSData\""]) {
            [proTypes addObject:SQLBLOB];
        } else if ([propertyType hasPrefix:@"Ti"]||[propertyType hasPrefix:@"TI"]||[propertyType hasPrefix:@"Ts"]||[propertyType hasPrefix:@"TS"]||[propertyType hasPrefix:@"TB"]||[propertyType hasPrefix:@"Tq"]||[propertyType hasPrefix:@"TQ"]) {
            [proTypes addObject:SQLINTEGER];
        } else {
            [proTypes addObject:SQLREAL];
        }
        
    }
    free(properties);
    
    return [NSDictionary dictionaryWithObjectsAndKeys:proNames,@"name",proTypes,@"type",nil];
}

/** 获取所有属性，包含主键pk */
+ (NSDictionary *)getAllProperties
{
    NSDictionary *dict = [self.class getPropertys];
    
    NSMutableArray *proNames = [NSMutableArray array];
    NSMutableArray *proTypes = [NSMutableArray array];
    [proNames addObject:primaryId];
    [proTypes addObject:[NSString stringWithFormat:@"%@ %@",SQLINTEGER,PrimaryKey]];
    [proNames addObjectsFromArray:[dict objectForKey:@"name"]];
    [proTypes addObjectsFromArray:[dict objectForKey:@"type"]];
    
    return [NSDictionary dictionaryWithObjectsAndKeys:proNames,@"name",proTypes,@"type",nil];
}

/** 数据库中是否存在表 */
+ (BOOL)isExistInTable
{
    __block BOOL res = NO;
    [fmdbHelper.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self.class replacedKeyFromTableName];
         res = [db tableExists:tableName];
    }];
    return res;
}

/** 获取列名 */
+ (NSArray *)getColumns
{
    NSMutableArray *columns = [NSMutableArray array];
     [fmdbHelper.dbQueue inDatabase:^(FMDatabase *db) {
         NSString *tableName = [self.class replacedKeyFromTableName];
         FMResultSet *resultSet = [db getTableSchema:tableName];
         while ([resultSet next]) {
             NSString *column = [resultSet stringForColumn:@"name"];
             [columns addObject:column];
         }
     }];
    return [columns copy];
}

/**
 * 创建表
 * 如果已经创建，返回YES
 */
+ (BOOL)createTable
{
    __block BOOL res = YES;
    [fmdbHelper.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSString *tableName = [self.class replacedKeyFromTableName];
        NSString *columeAndType = [self.class getColumeAndTypeString];
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@);",tableName,columeAndType];
        if (![db executeUpdate:sql]) {
            res = NO;
            *rollback = YES;
            return;
        };
        
        NSMutableArray *columns = [NSMutableArray array];
        FMResultSet *resultSet = [db getTableSchema:tableName];
        while ([resultSet next]) {
            NSString *column = [resultSet stringForColumn:@"name"];
            [columns addObject:column];
        }
        NSDictionary *dict = [self.class getAllProperties];
        NSArray *properties = [dict objectForKey:@"name"];
        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)",columns];
        //过滤数组
        NSArray *resultArray = [properties filteredArrayUsingPredicate:filterPredicate];
        for (NSString *column in resultArray) {
            NSUInteger index = [properties indexOfObject:column];
            NSString *proType = [[dict objectForKey:@"type"] objectAtIndex:index];
            NSString *fieldSql = [NSString stringWithFormat:@"%@ %@",column,proType];
            NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ ",NSStringFromClass(self.class),fieldSql];
            if (![db executeUpdate:sql]) {
                res = NO;
                *rollback = YES;
                return ;
            }
        }
    }];
    
    return res;
}

- (BOOL)saveOrUpdate
{
    if (![self judgePrimaryKey]) {
        return false;
    }
    
    id primaryValue = [self valueForKey:primaryId];
    if ([primaryId isEqualToString:@"pk"]) {
        if ([primaryValue intValue] <= 0) {
            return [self save];
        }else{
            self.pk = primaryValue;
            return [self update];
        }
    }else{
        if ([self isBlankString:primaryValue]) {
            return [self save];
        }else{
            return [self update];
        }
    }

}

- (BOOL)saveOrUpdateByColumnName:(NSString*)columnName AndColumnValue:(NSString*)columnValue
{
    if (![self judgePrimaryKey]) {
        return false;
    }
    
    id record = [self.class findFirstByCriteria:[NSString stringWithFormat:@"where %@ = %@",columnName,columnValue]];
    if (record) {
        
        id primaryValue = [record valueForKey:primaryId]; //取到了主键PK
        if ([primaryId isEqualToString:@"pk"]) {
            if ([primaryValue intValue] <= 0) {
                return [self save];
            }else{
                self.pk = primaryValue;
                return [self update];
            }
        }else{
            if ([self isBlankString:primaryValue]) {
                return [self save];
            }else{
                return [self update];
            }
        }
        
    }else{
        return [self save];
    }
}

- (BOOL)save
{
    NSString *tableName = [self.class replacedKeyFromTableName];
    NSMutableString *keyString = [NSMutableString string];
    NSMutableString *valueString = [NSMutableString string];
    NSMutableArray *insertValues = [NSMutableArray  array];
    for (int i = 0; i < self.columeNames.count; i++) {
        NSString *proname = [self.columeNames objectAtIndex:i];
        if ([proname isEqualToString:primaryId]) {
            continue;
        }
        [keyString appendFormat:@"%@,", proname];
        [valueString appendString:@"?,"];
        id value = [self valueForKey:proname];
        if (!value) {
            value = @"";
        }
        [insertValues addObject:value];
    }
    
    [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
    [valueString deleteCharactersInRange:NSMakeRange(valueString.length - 1, 1)];
    
    __block BOOL res = NO;
    [fmdbHelper.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", tableName, keyString, valueString];
        res = [db executeUpdate:sql withArgumentsInArray:insertValues];
        if ([primaryId isEqualToString:@"pk"]) {
            self.pk = res?[NSString stringWithFormat:@"%lld",db.lastInsertRowId]:@"-1";
        }else{
            self.pk = res?[self valueForKey:primaryId]:@"-1";
        }
        NSLog(res?@"插入成功":@"插入失败");
    }];
    return res;
}

/** 批量保存用户对象 */
+ (BOOL)saveObjects:(NSArray *)array
{
    //判断是否是JKBaseModel的子类
    for (wxs_fmdbModel *model in array) {
        if (![model isKindOfClass:[wxs_fmdbHelper class]]) {
            return NO;
        }
    }
    
    __block BOOL res = YES;
    // 如果要支持事务
    [fmdbHelper.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (wxs_fmdbModel *model in array) {
            NSString *tableName = [model.class replacedKeyFromTableName];
            NSMutableString *keyString = [NSMutableString string];
            NSMutableString *valueString = [NSMutableString string];
            NSMutableArray *insertValues = [NSMutableArray  array];
            for (int i = 0; i < model.columeNames.count; i++) {
                NSString *proname = [model.columeNames objectAtIndex:i];
                if ([proname isEqualToString:primaryId]) {
                    continue;
                }
                [keyString appendFormat:@"%@,", proname];
                [valueString appendString:@"?,"];
                id value = [model valueForKey:proname];
                if (!value) {
                    value = @"";
                }
                [insertValues addObject:value];
            }
            [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
            [valueString deleteCharactersInRange:NSMakeRange(valueString.length - 1, 1)];
            
            NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", tableName, keyString, valueString];
            BOOL flag = [db executeUpdate:sql withArgumentsInArray:insertValues];
            if ([primaryId isEqualToString:@"pk"]) {
                [self.class setValue:res?[NSString stringWithFormat:@"%lld",db.lastInsertRowId]:@"-1" forKey:@"pk"];
            }else{
                [self.class setValue:res?[self.class valueForKey:primaryId]:@"-1" forKey:@"pk"];
            }
            NSLog(flag?@"插入成功":@"插入失败");
            if (!flag) {
                res = NO;
                *rollback = YES;
                return;
            }
        }
    }];
    return res;
}

/** 更新单个对象 */
- (BOOL)update
{
    if (![self judgePrimaryKey]) {
        return false;
    }
    
    __block BOOL res = NO;
    [fmdbHelper.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self.class replacedKeyFromTableName];
        id primaryValue = [self valueForKey:primaryId];
        if (!primaryValue || primaryValue <= 0) {
            return ;
        }
        NSMutableString *keyString = [NSMutableString string];
        NSMutableArray *updateValues = [NSMutableArray  array];
        for (int i = 0; i < self.columeNames.count; i++) {
            NSString *proname = [self.columeNames objectAtIndex:i];
            if ([proname isEqualToString:primaryId]) {
                continue;
            }
            [keyString appendFormat:@" %@=?,", proname];
            id value = [self valueForKey:proname];
            if (!value) {
                value = @"";
            }
            [updateValues addObject:value];
        }
        
        //删除最后那个逗号
        [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ = ?;", tableName, keyString, primaryId];
        [updateValues addObject:primaryValue];
        res = [db executeUpdate:sql withArgumentsInArray:updateValues];
        NSLog(res?@"更新成功":@"更新失败");
    }];
    return res;
}

/** 批量更新用户对象*/
+ (BOOL)updateObjects:(NSArray *)array
{
    for (wxs_fmdbModel *tempModel in array) {
        if (![tempModel judgePrimaryKey]) {
            return false;
        }
    }
    
    for (wxs_fmdbModel *model in array) {
        if (![model isKindOfClass:[wxs_fmdbModel class]]) {
            return NO;
        }
    }
    __block BOOL res = YES;
    // 如果要支持事务
    [fmdbHelper.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (wxs_fmdbModel *model in array) {
            NSString *tableName = [self.class replacedKeyFromTableName];
            id primaryValue = [model valueForKey:primaryId];
            if (!primaryValue || primaryValue <= 0) {
                res = NO;
                *rollback = YES;
                return;
            }
            
            NSMutableString *keyString = [NSMutableString string];
            NSMutableArray *updateValues = [NSMutableArray  array];
            for (int i = 0; i < model.columeNames.count; i++) {
                NSString *proname = [model.columeNames objectAtIndex:i];
                if ([proname isEqualToString:primaryId]) {
                    continue;
                }
                [keyString appendFormat:@" %@=?,", proname];
                id value = [model valueForKey:proname];
                if (!value) {
                    value = @"";
                }
                [updateValues addObject:value];
            }
            
            //删除最后那个逗号
            [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
            NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@=?;", tableName, keyString, primaryId];
            [updateValues addObject:primaryValue];
            BOOL flag = [db executeUpdate:sql withArgumentsInArray:updateValues];
            NSLog(flag?@"更新成功":@"更新失败");
            if (!flag) {
                res = NO;
                *rollback = YES;
                return;
            }
        }
    }];
    
    return res;
}

/** 删除单个对象 */
- (BOOL)deleteObject
{
    if (![self judgePrimaryKey]) {
        return nil;
    }
    
    __block BOOL res = NO;
    [fmdbHelper.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self.class replacedKeyFromTableName];
        id primaryValue = [self valueForKey:primaryId];
        if (!primaryValue || primaryValue <= 0) {
            return ;
        }
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ?",tableName,primaryId];
        res = [db executeUpdate:sql withArgumentsInArray:@[primaryValue]];
         NSLog(res?@"删除成功":@"删除失败");
    }];
    return res;
}

/** 批量删除用户对象 */
+ (BOOL)deleteObjects:(NSArray *)array
{
    for (wxs_fmdbModel *tempModel in array) {
        if (![tempModel judgePrimaryKey]) {
            return false;
        }
    }
    
    for (wxs_fmdbModel *model in array) {
        if (![model isKindOfClass:[wxs_fmdbModel class]]) {
            return NO;
        }
    }
    
    __block BOOL res = YES;
    // 如果要支持事务
    [fmdbHelper.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (wxs_fmdbModel *model in array) {
            NSString *tableName = [self.class replacedKeyFromTableName];
            id primaryValue = [model valueForKey:primaryId];
            if (!primaryValue || primaryValue <= 0) {
                return ;
            }
            
            NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ?",tableName,primaryId];
            BOOL flag = [db executeUpdate:sql withArgumentsInArray:@[primaryValue]];
             NSLog(flag?@"删除成功":@"删除失败");
            if (!flag) {
                res = NO;
                *rollback = YES;
                return;
            }
        }
    }];
    return res;
}

/** 通过条件删除数据 */
+ (BOOL)deleteObjectsByCriteria:(NSString *)criteria
{
    __block BOOL res = NO;
    [fmdbHelper.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self.class replacedKeyFromTableName];
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ %@ ",tableName,criteria];
        res = [db executeUpdate:sql];
        NSLog(res?@"删除成功":@"删除失败");
    }];
    return res;
}

/** 通过条件删除 (多参数）--2 */
+ (BOOL)deleteObjectsWithFormat:(NSString *)format, ...NS_REQUIRES_NIL_TERMINATION
{
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    
    return [self deleteObjectsByCriteria:criteria];
}

/** 清空表 */
+ (BOOL)clearTable
{
    __block BOOL res = NO;
    [fmdbHelper.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self.class replacedKeyFromTableName];
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@",tableName];
        res = [db executeUpdate:sql];
        NSLog(res?@"清空成功":@"清空失败");
    }];
    return res;
}

/** 查询全部数据 */
+ (NSArray *)findAll
{
    return [self findByCriteria:@""];
}

+ (instancetype)findFirstWithFormat:(NSString *)format, ...NS_REQUIRES_NIL_TERMINATION
{
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    
    return [self findFirstByCriteria:criteria];
}

/** 查找某条数据 */
+ (instancetype)findFirstByCriteria:(NSString *)criteria
{
    NSArray *results = [self.class findByCriteria:criteria];
    if (results.count < 1) {
        return nil;
    }
    
    return [results firstObject];
}

+ (instancetype)findByPK:(NSString *)inPk
{
    NSString *condition = [NSString stringWithFormat:@"WHERE %@=%@",primaryId,inPk];
    return [self findFirstByCriteria:condition];
}

+ (NSArray *)findWithFormat:(NSString *)format, ...NS_REQUIRES_NIL_TERMINATION
{
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    
    return [self findByCriteria:criteria];
}

/** 通过条件查找数据 */
+ (NSArray *)findByCriteria:(NSString *)criteria
{
    NSMutableArray *users = [NSMutableArray array];
    [fmdbHelper.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self.class replacedKeyFromTableName];
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ %@",tableName,criteria];
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            wxs_fmdbModel *model = [[self.class alloc] init];
            for (int i=0; i< model.columeNames.count; i++) {
                NSString *columeName = [model.columeNames objectAtIndex:i];
                NSString *columeType = [model.columeTypes objectAtIndex:i];
                if ([columeName isEqualToString:[model.class primaryKey]]) {
                    NSString *tempPK = @"";
                    if ([columeType isEqualToString:SQLTEXT]) {
                        tempPK = [resultSet stringForColumn:columeName];
                    } else if ([columeType isEqualToString:SQLBLOB]) {
                        NSData *tempData = [resultSet dataForColumn:columeName];
                        tempPK = [[NSString alloc] initWithData:tempData  encoding:NSUTF8StringEncoding];
                    } else {
                        NSInteger number = [resultSet longLongIntForColumn:columeName];
                        tempPK = [NSString stringWithFormat:@"%ld",number];
                    }
                    [model setValue:tempPK forKey:columeName];
                }else{
                    if ([columeType isEqualToString:SQLTEXT]) {
                        [model setValue:[resultSet stringForColumn:columeName] forKey:columeName];
                    } else if ([columeType isEqualToString:SQLBLOB]) {
                        [model setValue:[resultSet dataForColumn:columeName] forKey:columeName];
                    } else {
                        [model setValue:[NSNumber numberWithLongLong:[resultSet longLongIntForColumn:columeName]] forKey:columeName];
                    }
                }
            }
            [users addObject:model];
            FMDBRelease(model);
        }
    }];
    
    return users;
}

#pragma mark - util method
+ (NSString *)getColumeAndTypeString
{
    NSMutableString* pars = [NSMutableString string];
    NSDictionary *dict = [self.class getAllProperties];
    
    NSMutableArray *proNames = [dict objectForKey:@"name"];
    NSMutableArray *proTypes = [dict objectForKey:@"type"];
    
    for (int i=0; i< proNames.count; i++) {
        [pars appendFormat:@"%@ %@",[proNames objectAtIndex:i],[proTypes objectAtIndex:i]];
        if(i+1 != proNames.count)
        {
            [pars appendString:@","];
        }
    }
    return pars;
}

- (NSString *)description
{
    NSString *result = @"";
    NSDictionary *dict = [self.class getAllProperties];
    NSMutableArray *proNames = [dict objectForKey:@"name"];
    for (int i = 0; i < proNames.count; i++) {
        NSString *proName = [proNames objectAtIndex:i];
        id  proValue = [self valueForKey:proName];
        result = [result stringByAppendingFormat:@"%@:%@\n",proName,proValue];
    }
    return result;
}

- (BOOL)judgePrimaryKey
{
    BOOL isLegal = NO;
    for (NSString *colume in self.columeNames) {
        if ([colume isEqualToString:[self.class primaryKey]]) {
            isLegal = YES;
            break;
        }
    }
    if (!isLegal) {
        NSLog(@"主键错误");
    }
    return isLegal;
}

- (BOOL)isBlankString:(NSString *)string{
    
    if (string==nil) {
        return NO;
    }
    if (string==NULL) {
        return NO;
    }
    if ([string isKindOfClass:[NSNull class]]) {
        return NO;
    }
    if ([string isEqualToString:@""]) {
        return NO;
    }
    return YES;
}

#pragma mark - must be override method
+ (NSArray *)ignoreKeys
{
    return [NSArray array];
}
+ (NSString *)primaryKey
{
    return @"pk";
}
+ (NSString *)replacedKeyFromTableName
{
    return NSStringFromClass([self class]);
}
@end
