//
//  LWGenericRequest.m
//  Mobile110
//
//  Copyright (c) 2014年 lvwan. All rights reserved.
//

#import "LWGenericRequest.h"
#import "ASIHttpRequest.h"
#import "ASIFormDataRequest.h"

#define METHOD_TYPE_GET  0
#define METHOD_TYPE_POST 1

#define _F(fmt, ...) [NSString stringWithFormat:fmt, ##__VA_ARGS__]
#define _LOG(fmt, ...)

@interface LWGenericRequest ()
@property(nonatomic, strong) ASIHTTPRequest *request;

- (id)init:(NSString *)url params:(NSDictionary *)params delegate:(id <LWRequestDelegate>)delegate clz:(__unsafe_unretained Class)clz;

- (ASIHTTPRequest *)newRequest:(int)methodType;

- (void)notifyError:(int)code msg:(NSString *)msg data:(id)data;

- (void)notifyComplete:(id)data;
@end

@implementation LWGenericRequest {
    NSString *_file_path;
    NSObject *_upload_file_object;
    int _method;
    NSString *_upload_file_key;
}

#pragma mark -- Get LWGenericRequest

+ (id)requestWith:(NSString *)url {
    return [[LWGenericRequest alloc] init:url params:nil delegate:nil clz:nil];
}

+ (id)requestWith:(NSString *)url params:(NSDictionary *)params {
    return [[LWGenericRequest alloc] init:url params:params delegate:nil clz:nil];
}

+ (id)requestWith:(NSString *)url clz:(Class)clz {
    return [[LWGenericRequest alloc] init:url params:nil delegate:nil clz:clz];
}

+ (id)requestWith:(NSString *)url params:(NSDictionary *)params delegate:(id <LWRequestDelegate>)delegate clz:(Class)clz {
    return [[LWGenericRequest alloc] init:url params:params delegate:delegate clz:clz];
}


#pragma mark -- GET|POST|UPLOAD|DOWNLOAD|CANCEL

- (void)doGet {
    [self sendRequest];
}

- (void)doSynchGet {
    self.sync = YES;
    [self sendRequest];
}

- (void)doPost {
    _method = METHOD_TYPE_POST;
    [self sendRequest];
}

- (void)doSynchPost {
    _method = METHOD_TYPE_POST;
    self.sync = YES;
    [self sendRequest];
}

- (void)doDownloadFile:(NSString *)file_path {
    _file_path = file_path;
    self.timeOutSeconds = 120.0f;
    [self sendRequest];
}

- (void)doDownloadFile:(NSString *)file_path cacheable:(BOOL)cacheable {
    if (cacheable && [[NSFileManager defaultManager] fileExistsAtPath:file_path]) {
        _file_path = file_path;
        [self notifyComplete:_file_path];
        return;
    }
    [self doDownloadFile:file_path];
}

- (void)doUploadFile:(NSString *)file_path forKey:(NSString *)key {
    _upload_file_object = file_path;
    _upload_file_key = key;
    _method = METHOD_TYPE_POST;
    self.timeOutSeconds = 120.0F;
    [self sendRequest];
}


- (void)doUploadMultiFiles:(NSArray *)files forKey:(NSString *)key {
    _upload_file_object = files;
    _upload_file_key = key;
    _method = METHOD_TYPE_POST;
    self.timeOutSeconds = 120.0F;
    [self sendRequest];
}


- (void)cancel {
    if (self.finished)return;
    self.finished = YES;
    [self cancelRequest];
    [self notifyFinished:ERR_NO_CANCEL msg:@"cancel" data:nil];
}

- (void)cancelRequest {
    if (_request != nil) {
        _request.delegate = nil;
        [_request clearDelegatesAndCancel];
        _request = nil;
    }
}

#pragma mark -- ASIHttpRequestDelegate

- (void)requestFinished:(ASIHTTPRequest *)request {
    if (self.finished)return;
    self.finished = YES;
    if (_file_path != nil) {
        [self notifyComplete:_file_path];
        return;
    }
    NSData *data = [request responseData];
    NSLog(@"%@ response date:\n%@", _url, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    NSError *err = nil;
    id result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments | NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves error:&err];
    if (err != nil) {
        NSLog(@"json parse error:%d, %@", err.code, err.description);
        [self notifyError:ERR_NO_JSON_ERROR msg:err.localizedDescription data:nil];
        return;
    }
    NSNumber *error_no = (NSNumber *) [result valueForKey:@"error"];
    id value = result[@"data"];
    if ([error_no intValue] != ERR_NO_NO_ERROR) {
        [self notifyError:[error_no intValue] msg:[result valueForKey:@"message"] data:value];
        return;
    }
    if (_clz != nil) {
        NSObject *defaultObject = [[_clz alloc] init];
        if ([value isKindOfClass:[NSDictionary class]]) {
            NSObject *object = [_clz alloc];
            @try {
                object = [(JSONModel *) object initWithDictionary:value error:&err];
                if (err != nil) {
                    NSLog(@"json model error:%@", err.description);
                }
            } @catch (NSException *exception) {
                NSLog(@"json model error:%@", exception.description);
            }
            value = object != nil ? object : defaultObject;
        }
        else if ([value isKindOfClass:[NSArray class]]) {
            NSArray *resArray = (NSArray *) value;
            NSMutableArray *array = [NSMutableArray array];
            for (NSUInteger i = 0; i < resArray.count; ++i) {
                NSDictionary *json = resArray[i];
                NSObject *object = [_clz alloc];
                err = nil;
                object = [(JSONModel *) object initWithDictionary:json error:&err];
                if (err != nil) {
                    _LOG(@"json model error:%@", err.description);
                }
                [array addObject:object withDefaultValue:defaultObject];
            }
            value = array;
        }
    }
    [self notifyComplete:value];
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSString *msg = nil;
    if (request.error != nil) {
        msg = request.error.localizedDescription;
    }
    [self notifyError:ERR_NO_UNKNOWN msg:msg data:nil];
}

#pragma mark -- Private

- (void)notifyStart {
//    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationLWRequestDidCreate object:self];
    _LOG(@"request did create `%@(%@)`", _url, _uniqueIdentifier);
}

- (void)notifyError:(int)code msg:(NSString *)msg data:(id)data {
    __strong LWGenericRequest *selfRequest = self;
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    
    if (_delegate != nil && [_delegate respondsToSelector:@selector(requestOnError:err_no:msg:)]) {
        [_delegate requestOnError:self err_no:code msg:msg];
    }
    if (_delegate != nil && [_delegate respondsToSelector:@selector(requestOnComplete:result:err_no:msg:)]) {
        [_delegate requestOnComplete:self result:data err_no:code msg:msg];
    }
    if (self.onError != nil) {
        self.onError(code, msg);
    }
    if (self.onComplete != nil) {
        self.onComplete(data, code, msg);
    }
    [selfRequest notifyFinished:code msg:msg data:data];
}

- (void)notifyComplete:(id)data {
    __strong LWGenericRequest *selfRequest = self;
    if (_delegate != nil && [_delegate respondsToSelector:@selector(requestOnSuccess:result:)]) {
        [_delegate requestOnSuccess:self result:data];
    }
    if (_delegate != nil && [_delegate respondsToSelector:@selector(requestOnComplete:result:err_no:msg:)]) {
        [_delegate requestOnComplete:self result:data err_no:0 msg:nil];
    }
    if (self.onSuccess != nil) {
        self.onSuccess(data);
    }
    if (self.onComplete != nil) {
        self.onComplete(data, ERR_NO_NO_ERROR, nil);
    }
    [selfRequest notifyFinished:ERR_NO_NO_ERROR msg:nil data:data];
}

- (void)notifyFinished:(int)code msg:(NSString *)msg data:(id)data {
    if (code != ERR_NO_NO_ERROR) {
        NSLog(@"request did finish `%@(%@)` with error`%@(%d)`, time spent %.2f", _url, _uniqueIdentifier, msg, code, _NOW - self.requestTime);
    } else {
        NSLog(@"request did finish `%@(%@)`, time spent %.2f", _url, _uniqueIdentifier, _NOW - self.requestTime);
    }
}

- (ASIHTTPRequest *)newRequest:(int)methodType {
    if ([[LWFastServiceNetWorkState sharedInstance] getNetWorkState] == NotReachable) {
        [self notifyError:ERR_NO_NO_NETWORK msg:@"无可用网络" data:nil];
        return nil;
    }
    NSMutableString *url = [NSMutableString stringWithFormat:@"%@%@",
                                                            You_domain_server, self.url];

    if (methodType == METHOD_TYPE_GET && _params != nil) {
        NSMutableArray *paramArr = [NSMutableArray array];
        for (NSString *key in _params) {
            [paramArr addObject:_F(@"%@=%@", key,
                    [[self getParamValue:_params key:key] ys_URLEncodedString])];
        }
        [url appendFormat:@"%@%@",
                          [url rangeOfString:@"?"].length != 0 ? @"&" : @"?",
                          [paramArr componentsJoinedByString:@"&"]];
    }
    ASIHTTPRequest *req = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:url]];
    BOOL isPOST = methodType == METHOD_TYPE_POST;
    if (isPOST) {
        req = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:url]];
        for (NSString *key in _params) {
            [((ASIFormDataRequest *) req) addPostValue:[self getParamValue:_params key:key] forKey:key];
        }
        [req setRequestMethod:@"POST"];
    }
    else {
        [req setRequestMethod:@"GET"];
    }
    req.delegate = self;
    req.numberOfTimesToRetryOnTimeout = 0;

// you can add requestheader here
    
    [req addRequestHeader:@"nettype" value:NetWorkType];
    return req;
}

- (id)getParamValue:(NSDictionary *)params key:(NSString *)key {
    id object = params[key];
    if (!object)return @"";
    if ([object isKindOfClass:[NSDictionary class]]) {
        object = [JSONModel toJSONString:object];
    }
    else if ([object isKindOfClass:[LWJSONModel class]]) {
        object = [((JSONModel *) object) toJSONString];
    }
    return _F(@"%@", object);
}

- (id)init:(NSString *)url params:(NSDictionary *)params delegate:(id <LWRequestDelegate>)delegate clz:(__unsafe_unretained Class)clz {
    if (self = [super init]) {
        self.url = url;
        _params = params;
        _delegate = delegate;
        _clz = clz;
        _method = METHOD_TYPE_GET;
        self.timeOutSeconds = 20.0F;
        self.sync = NO;
        _uniqueIdentifier = _F(@"%d_%d", (int) [[NSDate date] timeIntervalSince1970], [self.url hash]);
    }
    return self;
}

- (void)dealloc {
    [self cancel];
    _LOG(@"request dealloced %@, %@", _uniqueIdentifier, self.url);
}

#pragma mark - real send request

- (void)sendRequest {
    if (_request != nil) {
        _LOG(@"request has sent, please don't recall it.", @"");
        return;
    }
    self.finished = NO;
    _request = [self newRequest:_method];
    _request.timeOutSeconds = self.timeOutSeconds;
    _requestTime = _NOW;
    if (_file_path != nil)
        [_request setDownloadDestinationPath:_file_path];
    if (_upload_file_key != nil && _method == METHOD_TYPE_POST && _upload_file_object!=nil) {
        ASIFormDataRequest *formRequest = (ASIFormDataRequest *) _request;
        if ([_upload_file_object isKindOfClass:[NSString class]]){
            [formRequest addFile:(NSString *)_upload_file_object forKey:_upload_file_key];
        }
        else if ([_upload_file_object isKindOfClass:[NSData class]]){
            [formRequest addData:(NSData *)_upload_file_object forKey:_upload_file_key];
        }
        else if ([_upload_file_object isKindOfClass:[NSArray class]]){
            int index = 1;
            for (NSObject *obj in (NSArray*)_upload_file_object) {
                NSString *upload_file_key = _F(@"%@%d", _upload_file_key, index++);
                if ([obj isKindOfClass:[NSString class]]){
                    [formRequest addFile:(NSString *)obj forKey:upload_file_key];
                }
                else if ([obj isKindOfClass:[NSData class]]){
                    [formRequest addData:(NSData *)obj forKey:upload_file_key];
                }
            }
        }
    }
    if (self.sync) {
        [_request startSynchronous];
    } else {
        [_request startAsynchronous];
    }
    [self notifyStart];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.url forKey:@"url"];
    if (_params != nil)
        [coder encodeObject:_params forKey:@"params"];
    if (_clz != nil)
        [coder encodeObject:_clz forKey:@"clz"];
    if (_file_path != nil)
        [coder encodeObject:_file_path forKey:@"file_path"];
    if (_upload_file_object != nil)
        [coder encodeObject:_upload_file_object forKey:@"upload_file_object"];
    if (_upload_file_key != nil)
        [coder encodeObject:_upload_file_key forKey:@"upload_file_key"];
    [coder encodeBool:self.sync forKey:@"sync"];
    [coder encodeInt32:_method forKey:@"method"];
    [coder encodeDouble:_request.timeOutSeconds forKey:@"timeOutSeconds"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.url = [coder decodeObjectForKey:@"url"];
        _params = [coder decodeObjectForKey:@"params"];
        _clz = [coder decodeObjectForKey:@"clz"];
        _file_path = [coder decodeObjectForKey:@"file_path"];
        _upload_file_object = [coder decodeObjectForKey:@"upload_file_object"];
        _upload_file_key = [coder decodeObjectForKey:@"upload_file_key"];
        self.sync = [coder decodeBoolForKey:@"sync"];
        _method = [coder decodeInt32ForKey:@"method"];
        self.timeOutSeconds = [coder decodeDoubleForKey:@"timeOutSeconds"];
        _uniqueIdentifier = _F(@"%d_%d", (int) [[NSDate date] timeIntervalSince1970], [self.url hash]);
    }
    return self;
}

@end
