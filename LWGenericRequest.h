//
//  LWGenericRequest.h
//  Mobile110
//
//  Copyright (c) 2014年 lvwan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASIHTTPRequestDelegate.h"

#define ERR_NO_NO_ERROR        0
#define ERR_NO_UNKNOWN         810000
#define ERR_NO_USER_INVALID    6001
#define ERR_NO_USER_MUST_LOGIN 6002
#define ERR_NO_USER_NOT_FINISH 6003
#define ERR_NO_PINIT_FAILED    6010
#define ERR_NO_USER_KICKED     6015
#define ERR_NO_VERIFY_CODE     6011
#define ERR_NO_3RD_UNCOMPLETE  6024
#define ERR_NO_NO_NETWORK      89999
#define ERR_NO_JSON_ERROR      89998
#define ERR_NO_CANCEL          89997
#define ERR_NO_TIMEOUT         89996
#define ERR_NO_NEED_LOOP       60401
#define ERR_NO_TASK_FAILED     60402

@class LWGenericRequest;

@protocol LWRequestDelegate <NSObject>

@optional
- (void)requestOnSuccess:(LWGenericRequest *)request result:(id)data;

- (void)requestOnError:(LWGenericRequest *)request err_no:(int)err_no msg:(NSString *)msg;

- (void)requestOnComplete:(LWGenericRequest *)request result:(id)data err_no:(int)err_no msg:(NSString *)msg;
@end

@interface LWGenericRequest : NSObject <ASIHTTPRequestDelegate, NSCoding> {
}

@property(nonatomic) NSDictionary *params;
@property(nonatomic, weak) id <LWRequestDelegate> delegate;
@property(nonatomic, unsafe_unretained) Class clz;
@property(copy) void (^onSuccess)(id);
@property(copy) void (^onComplete)(id, int, NSString *);
@property(copy) void (^onError)(int, NSString *);
@property(nonatomic, strong, readonly) id uniqueIdentifier;
@property(nonatomic, readonly) NSTimeInterval requestTime;

@property(nonatomic) BOOL finished;

@property(nonatomic) double timeOutSeconds;

@property(nonatomic, copy) NSString *url;

@property(nonatomic) BOOL sync;

+ (id)requestWith:(NSString *)url;

+ (id)requestWith:(NSString *)url params:(NSDictionary *)params;

+ (id)requestWith:(NSString *)url clz:(Class)clz;

+ (id)requestWith:(NSString *)url params:(NSDictionary *)params delegate:(id <LWRequestDelegate>)delegate clz:(Class)clz;

+ (NSString *)userAgent;

+ (NSArray *)signArray;

- (void)doGet;

- (void)doPost;

- (void)doSynchPost;

- (void)doDownloadFile:(NSString *)file_path;

- (void)doDownloadFile:(NSString *)file_path cacheable:(BOOL)cacheable;

- (void)doUploadFile:(NSString *)file_path forKey:(NSString *)key;

- (void)doUploadMultiFiles:(NSArray *)files forKey:(NSString *)key;

- (void)cancel;

- (void)sendRequest;

- (void)doSynchGet;

@end
