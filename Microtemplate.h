/*
 *  Microtemplate.h
 *
 *  - Requires RegexKitLite
 *
 *  Copyright 2009 Adam Ballai <aballai@gmail.com>
 */

#import <Foundation/Foundation.h>
#import "RegexKitLite.h"

#define MICROTEMPLATE_VERSION "2.0"
#define REGEX_MARKER @"<!---\\s*(.*?)\\s*--->"
#define MICROTEMPLATE_BLOCKS @"B"

@interface MicrotemplateLiteral : NSString {
}
@end

@interface MicrotemplateString : NSString {
}
@end

@interface MicrotemplateToken : NSObject {
	id value;
}
@property (nonatomic, retain) id value;

- (MicrotemplateToken *)initWithString: (NSString *)str;

@end

@interface MicrotemplateBegin : MicrotemplateToken {
}
@end

@interface MicrotemplateEnd : MicrotemplateToken {
}
@end

@interface MicrotemplateComment : MicrotemplateToken {
}
@end

@interface MicrotemplateContent: MicrotemplateToken {
}
@end

@interface MicrotemplateUnexpectedEndMarker : NSException {
}
@end

@interface MicrotemplateUnknownBlock : NSException {
}
@end

@interface MicrotemplateUnterminatedBlock : NSException {
	
}

@end



@interface Microtemplate : NSObject {
	NSMutableDictionary *subBlocks;
	NSMutableDictionary *outBuffers;
	NSMutableDictionary *data;
}

@property (nonatomic, retain) NSMutableDictionary *subBlocks;
@property (nonatomic, retain) NSMutableDictionary *outBuffers;
@property (nonatomic, retain) NSMutableDictionary *data;

- (Microtemplate *)initWithString: (NSString *)str;

+ (Microtemplate *)from_file: (NSString *)filename;
+ (Microtemplate *)from_string: (NSString *)str;
+ (MicrotemplateLiteral *)literal: (NSString *)value;

- (NSArray *)blocks;
- (NSString *)render: (NSString *)path 
							env: (NSMutableDictionary *)environment;
- (MicrotemplateString *)renderEach: (NSString *)path
								env: (NSArray *)environment
						   defaults: (NSDictionary *)defaultEnvironment;
- (MicrotemplateString *)evaluate: (NSString *)str
							  env: (NSDictionary *)environment;
- (void)inject: (NSString *)key
						  value: (NSString *)value
						    env: (NSMutableDictionary *)environment;			
- (NSArray *)splitMarker: (NSString *)str;
- (MicrotemplateToken *)lexCommand: (NSString *)str;
- (NSArray *)lex: (NSString *)str;
- (MicrotemplateString *)cleanName: (NSString *)str;
- (MicrotemplateString *)interpolate: (NSString *)str
								 env: (NSDictionary *)environment;

@end

@interface HTMLMicrotemplate : NSObject {
}

- (MicrotemplateString *)stringify: (id)object;
- (MicrotemplateString *)stringifyAll: (id)object;

@end
