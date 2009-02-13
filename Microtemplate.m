/*
 *  Microtemplate.m
 *
 *  Copyright 2009 Adam Ballai
 *
 *  Example Usage:
 *  Initializers
 *	NSString *defaultTemplatePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"material_detail.html"];
 *	Microtemplate *mtpl = [Microtemplate from_file:defaultTemplatePath];
 *	Microtemplate *mtpl = [[Microtemplate alloc] initWithString:@"<!--- BEGIN: test --->$test<!--- END: test --->"];
 *
 *  Rendering:
 *	NSDictionary *env = [NSDictionary dictionaryWithObject:@"test" forKey:@"test"];
 *	NSString *test = [mtpl render:@"test" env:env];
 */

#import "Microtemplate.h"
#import "RegexKitLite.h"

@implementation Microtemplate

@synthesize subBlocks;
@synthesize outBuffers;
@synthesize data;

+ (Microtemplate *)from_file: (NSString *)filename {
	NSString *contents = [NSString stringWithContentsOfFile:filename];
	Microtemplate *mtpl = [[Microtemplate alloc] initWithString:contents];
	return mtpl;
}

+ (Microtemplate *)from_string: (NSString *)str {
	Microtemplate *mtpl = [[Microtemplate alloc] initWithString:str];
	return mtpl;
}

+ (MicrotemplateLiteral *)literal: (NSString *)value {
	return [MicrotemplateLiteral stringWithString:value];
}

- (Microtemplate *)init { 
	subBlocks = [NSMutableDictionary dictionary];
	outBuffers = [NSMutableDictionary dictionary];
	data = [NSMutableDictionary dictionary];
	return self;
}

- (Microtemplate *)initWithString: (NSString *)str { 
	[self init];
	MicrotemplateToken *token = nil;
	id item = nil;
	NSEnumerator *f1 = nil;
	NSEnumerator *f2 = nil;
	NSArray *tokens = [[self lex:str] retain];
	NSMutableArray *stack = [[NSMutableArray array] retain];
	NSMutableDictionary *dataBuffers = [[NSMutableDictionary dictionary] retain];
	NSString *path;
	
	f1 = [[tokens objectEnumerator] retain];
	
	while(token = [f1 nextObject]) {
		path = [[stack componentsJoinedByString:@"."] retain];
		if([stack count] && ![dataBuffers objectForKey:path]) {
			[dataBuffers setObject:[NSMutableDictionary dictionary] forKey:path];
		}
		if([token isKindOfClass:[MicrotemplateComment class]]) {
			// Skip comments
		} else if ([token isKindOfClass:[MicrotemplateBegin class]]) {
			NSString *name = [[token value] retain];
			if([stack count]) {
				NSMutableDictionary *subBlock = [self.subBlocks objectForKey:path];
				if(!subBlock) {
					subBlock = [[NSMutableDictionary dictionary] retain];
					[self.subBlocks setObject:subBlock forKey:path];
				}
				[subBlock setObject:[[NSMutableDictionary dictionary] retain] forKey:name];
				NSMutableArray *blocks = [[dataBuffers objectForKey:path] objectForKey:MICROTEMPLATE_BLOCKS];
				if(!blocks) {
					blocks = [[NSMutableArray array] autorelease];
					[[dataBuffers objectForKey:path] setObject:blocks forKey:MICROTEMPLATE_BLOCKS];
				}
				NSString *beginMarker = [NSString stringWithFormat:@"{$__in_%@}", [self cleanName:name]];
				[blocks addObject:beginMarker];
				
			}
			[stack addObject:name];

		} else if ([token isKindOfClass:[MicrotemplateEnd class]]) {
			NSString *name = [[token value] autorelease];		
			NSString *top = ![stack count] == 0? @"" : [stack lastObject];
			if([name length] > 0 && [name compare:top]) {
				@try {
					[stack removeLastObject];
				}
				@catch (NSException * e) {
					@throw [MicrotemplateUnexpectedEndMarker exceptionWithName:@"UnexceptedEndMarker" reason:name userInfo:nil];
				}
			} else {
				@throw [MicrotemplateUnexpectedEndMarker exceptionWithName:@"UnexceptedEndMarker" reason:name userInfo:nil];
			}
		} else {
			assert([token isKindOfClass:[MicrotemplateContent class]]);
			NSMutableString *content = [[token value] retain];
			if([stack count]) {
				NSMutableDictionary *dataBuffer = [dataBuffers objectForKey:path];
			    if(!dataBuffer) {
					dataBuffer = [[NSMutableDictionary alloc] dictionary];
					[dataBuffers setObject:dataBuffer forKey:path];
				}
				NSMutableArray *blocks = [dataBuffer objectForKey:MICROTEMPLATE_BLOCKS];
				if(!blocks) {
					blocks = [[NSMutableArray array] retain];
					[[dataBuffers objectForKey:path] setObject:blocks forKey:MICROTEMPLATE_BLOCKS];
				}
				[blocks addObject:[content stringByReplacingOccurrencesOfRegex:@"/^(\\s*)/" withString:@""]];
				
			}
		}
	}
	
	if(![stack count]) {
		f2 = [[dataBuffers keyEnumerator] retain];
		id key = nil;
		while(key = [f2 nextObject]) {
			[self.data setObject:[[[dataBuffers	objectForKey:key] objectForKey:MICROTEMPLATE_BLOCKS] componentsJoinedByString:@""] forKey:key];
		}
	} else {
		@throw [MicrotemplateUnterminatedBlock exceptionWithName:@"UnterminatedBlock" reason:[stack lastObject] userInfo:nil];
	}
	
	[token release];
	[tokens release];
	[stack release];
	[dataBuffers release];
	[f1 release];
	[f2 release];
	return self;
}

- (NSArray *)blocks {
	return [data allKeys];
}

- (NSString *)render: (NSString *)path
				 env: (NSMutableDictionary *)environment {
	if(![data objectForKey:path]) {
		@throw [MicrotemplateUnknownBlock exceptionWithName:@"UnknownBlock" reason:path userInfo:nil];
	}
	
	// TODO: implement ${}
	NSArray *pathComponents = [path componentsSeparatedByString:@"."];
	id block = subBlocks;

	if(pathComponents && [pathComponents count] > 0) {
		for(NSString *component in pathComponents) {
			block = [block objectForKey:component];
		}
	}
	if([block count] > 0) {
		NSEnumerator *f = [block keyEnumerator];	
		id key = nil;
		while(key = [f nextObject]) {
			NSString *varName = [NSString stringWithFormat:@"__in_%@", [self cleanName:key]];
			NSString *subPath = [NSString stringWithFormat:@"%@.%@", path, key];
			NSString *subContents = @"";
			if([outBuffers objectForKey:subPath]) {
				subContents = [[outBuffers objectForKey:subPath] componentsJoinedByString:@""];
				[outBuffers removeObjectForKey:subPath];
			}
			[self inject:varName value:subContents env:environment];
		}
	}
	
	NSString *out = [self evaluate:[data objectForKey:path] env:environment];
	NSRange pathRange = [path rangeOfString:@"."];
	if(pathRange.length > 0) {
		NSMutableArray *buf = [outBuffers objectForKey:path];
		if(!buf) {
			buf = [NSMutableArray array];
			[outBuffers setObject:buf forKey:path];
		}
		[buf addObject:out];
	}
	return (MicrotemplateString*)out;
}

- (MicrotemplateString *)renderEach: (NSString *)path
								env: (NSArray *)environment
						   defaults: (NSDictionary *)defaultEnvironment {
	NSMutableString *out;
	NSEnumerator *f = [environment objectEnumerator];
	
	id env = nil;
	while(env = [f nextObject]) {
		NSMutableDictionary	*mergedEnv = [NSMutableDictionary dictionaryWithDictionary:defaultEnvironment];
		[mergedEnv addEntriesFromDictionary:env];
		[out appendString:[self render:path env:mergedEnv]];
	}
	
	return [MicrotemplateString stringWithString:out];
}


- (MicrotemplateString *)evaluate: (NSString *)str
							  env: (NSDictionary *)environment {
	return [self interpolate:str env:environment];
}

- (void)inject: (NSString *)key
		 value: (NSString *)val
		   env: (NSMutableDictionary *)environment {
	[environment setObject:val forKey:key];
}

- (NSArray *)splitMarker: (NSString *)str {
	NSArray *components = [str componentsSeparatedByString:@":"];
	if([components count] >= 2) {
		NSString * key = [[components objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString * val = [[components objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		return [NSArray arrayWithObjects:key, val, nil];
	} else {
		NSString * key = [[components objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		return [NSArray arrayWithObjects:key, @"", nil];
	}
}

- (MicrotemplateToken *)lexCommand: (NSString *)str {
	NSArray *marker = [self splitMarker:str];
	NSString *cmd = [[[marker objectAtIndex:0] lowercaseString] retain];
	NSString *name = [[[marker objectAtIndex:1] lowercaseString] retain];
	if([cmd isEqual:@"begin"]) {
		return [[MicrotemplateBegin alloc] initWithString:name];
	} else if ([cmd isEqual:@"end"]) {
		return [[MicrotemplateEnd alloc] initWithString:name];
	} else {
		return [[MicrotemplateComment alloc] initWithString:str];
	}
}

- (NSArray *)lex: (NSString *)str {
	NSArray *chunks = [[str componentsSeparatedByRegex:REGEX_MARKER] retain];
	NSMutableArray *result = [NSMutableArray array];
	BOOL is_delim = TRUE;
	for(NSString *chunk in chunks) {
		is_delim = !is_delim;
		if(is_delim) {
			[result	addObject:[self lexCommand:chunk]];
		} else {
			[result addObject:[[MicrotemplateContent alloc] initWithString:chunk]];
		}
	}
	
	return [NSArray arrayWithArray:result];
}

- (MicrotemplateString *)cleanName: (NSString *)str {
	return (MicrotemplateString *)[str stringByReplacingOccurrencesOfRegex:@"[^A-Za-z0-9_]" withString:@"__"];
}

- (MicrotemplateString *)interpolate: (NSString *)str
								env: (NSDictionary *)environment {
	NSString *out = str;
	NSString *regexComponent = @"(\\{?\\$[A-Za-z_][A-Za-z0-9_]*\\}?)";
	NSRange rangeMatch = {0, [str length]};
	NSString* matches = [str stringByMatching:regexComponent inRange:rangeMatch];
	while([out isMatchedByRegex:regexComponent inRange:rangeMatch]) {
		rangeMatch = [out rangeOfRegex:regexComponent inRange:rangeMatch];
		NSString *replacement = [environment objectForKey:[matches stringByReplacingOccurrencesOfRegex:@"[\\{\\$\\}]" withString:@""]];
		out = [out stringByReplacingOccurrencesOfString:matches withString:replacement];
		
		rangeMatch.location += rangeMatch.length - [matches length] + [replacement length];
		rangeMatch.length = [out length] - rangeMatch.location;

		matches = [out stringByMatching:regexComponent inRange:rangeMatch];
	}
	return (MicrotemplateString *)out;
}

@end

@implementation HTMLMicrotemplate 
	
- (MicrotemplateString *)stringify: (id)object {
	return nil;
}

- (MicrotemplateString *)stringifyAll: (id)object {
	return nil;
}
@end

@implementation MicrotemplateLiteral 
@end

@implementation MicrotemplateString
@end

@implementation MicrotemplateToken

@synthesize value;

- (MicrotemplateToken *)initWithString: (NSString *)str {
	[self init];
	value = str;
	return self;
}

@end

@implementation MicrotemplateBegin
@end

@implementation MicrotemplateEnd
@end

@implementation MicrotemplateComment
@end

@implementation MicrotemplateContent
@end

@implementation MicrotemplateUnexpectedEndMarker
@end

@implementation MicrotemplateUnknownBlock
@end

@implementation MicrotemplateUnterminatedBlock
@end
