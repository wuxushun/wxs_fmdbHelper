//
//  wxs_fmdbModel.h
//  wxs_fmdbManager
//
//  Created by macmini on 2016/10/25.
//  Copyright © 2016年 wxs. All rights reserved.
//

#import <Foundation/Foundation.h>

/** SQLite五种数据类型 */
#define SQLTEXT     @"TEXT"
#define SQLINTEGER  @"INTEGER"
#define SQLREAL     @"REAL"
#define SQLBLOB     @"BLOB"
#define SQLNULL     @"NULL"
#define PrimaryKey  @"primary key"

#define primaryId   [self.class primaryKey]

@interface wxs_fmdbModel : NSObject

/** 默认自增主键，指定主键后将返回指定主键值 */
@property (strong, nonatomic, readonly) NSString            *pk;
/** 列名 */
@property (retain, readonly, nonatomic) NSMutableArray      *columeNames;
/** 列类型 */
@property (retain, readonly, nonatomic) NSMutableArray      *columeTypes;


#pragma mark -----------表操作
/** 创建表  */
+ (BOOL)createTable;
/** 数据库中是否存在表  */
+ (BOOL)isExistInTable;
/** 表中所有字段  */
+ (NSArray *)getColumns;
/** 清空表  */
+ (BOOL)clearTable;



#pragma mark -----------增
/** 保存单个数据 */
- (BOOL)save;
/** 批量保存数据 */
+ (BOOL)saveObjects:(NSArray *)array;


#pragma mark -----------改
/** 更新单个数据 */
- (BOOL)update;
/** 批量更新数据*/
+ (BOOL)updateObjects:(NSArray *)array;


#pragma mark -----------自动判断增或改
/** 保存或更新
 * 如果不存在主键，保存，
 * 有主键，则更新
 */
- (BOOL)saveOrUpdate;
/** 保存或更新
 * 如果根据特定的列数据可以获取记录，则更新，
 * 没有记录，则保存
 */
- (BOOL)saveOrUpdateByColumnName:(NSString*)columnName AndColumnValue:(NSString*)columnValue;



#pragma mark -----------删
/** 删除单个数据 */
- (BOOL)deleteObject;
/** 批量删除数据 */
+ (BOOL)deleteObjects:(NSArray *)array;
/** 通过条件删除数据 */
+ (BOOL)deleteObjectsByCriteria:(NSString *)criteria;
/** 通过条件删除 (格式化多参数）--2 */
+ (BOOL)deleteObjectsWithFormat:(NSString *)format, ...NS_REQUIRES_NIL_TERMINATION;



#pragma mark -----------单表查询
/** 查询全部数据 */
+ (NSArray *)findAll;
/** 通过主键查询 */
+ (instancetype)findByPK:(NSString *)inPk;
/** 查找某条数据 (格式化多参数） */
+ (instancetype)findFirstWithFormat:(NSString *)format, ...NS_REQUIRES_NIL_TERMINATION;
/** 查找某条数据 */
+ (instancetype)findFirstByCriteria:(NSString *)criteria;
/** 通过条件查找数据 这样可以进行分页查询 @" WHERE pk > 5 limit 10"  */
+ (NSArray *)findByCriteria:(NSString *)criteria;
/** 查找多条数据 (格式化多参数） */
+ (NSArray *)findWithFormat:(NSString *)format, ...NS_REQUIRES_NIL_TERMINATION;







#pragma mark -----------以下方法如需使用请重写
/**
 忽略创建/写入数据库字段,重写此方法返回字段名数组
 
 @return 字段名(model属性名)数组
 */
+ (NSArray *)ignoreKeys;

/**
 指定主键字段(如忽略则默认创建pk字段作为主键 int自增)
 
 @return 主键字段
 */
+ (NSString *)primaryKey;

/**
 如果重写将映射返回的字符串作为表名
 
 @return 表名
 */
+ (NSString *)replacedKeyFromTableName;


@end
