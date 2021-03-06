
/*
 * The Cheat - The legendary universal game trainer for Mac OS X.
 * http://www.brokenzipper.com/trac/wiki/TheCheat
 *
 * Copyright (c) 2003-2011, Charles McGarvey et al.
 *
 * Distributable under the terms and conditions of the 2-clause BSD
 * license; see the file COPYING for the legal text of the license.
 */


#import "SearchContext.h"


@implementation SearchContext


#pragma mark Initialization

/*
 * There isn't really a designated initializer because the initialization of the types
 * of searches vary way too much.
 */

- (id)initWithPID:(pid_t)pid searchOperator:(TCSearchOperator)op value:(Variable *)val
{
	unsigned valueSize;
	
	if ( [super init] ) {
		value = [val retain];
		if ( !value ) {
			[self release];
			return nil;
		}
		valueSize = [value valueSize];
		process = pid;
		_variableType = [value type];
		_integerSign = [value integerSign];
		_operator = op;
		_searchType = TCGivenValue;
		compareFunc = [self compareFunction];
		
		// allocate the memory objects which will be used during the search
		regionCount = VMCountRegionsWithAttributes( process, VMREGION_READABLE | VMREGION_WRITABLE );
		addresses = TCMakeArray( TC_BUFFER_SIZE / sizeof(TCAddress), sizeof(TCAddress) );
		values = TCMakeArray( TC_BUFFER_SIZE / valueSize, valueSize );
		regions = TCMakeArray( 0, sizeof(TCAddress) );
		perRegion = TCMakeArray( 0, sizeof(unsigned) );
		addressPtr = TCArrayBytes( addresses );
		valuePtr = TCArrayBytes( values );
		
		ChazLog( @"SearchContext: varType=%i, intSign=%i, op=%i, value=%@", _variableType, _integerSign, _operator, [value stringValue] );
	}
	return self;
}

- (id)initWithLastContext:(SearchContext *)context searchOperator:(TCSearchOperator)op
{
	unsigned valueSize;
	
	if ( [super init] ) {
		if ( !context ) {
			[self release];
			return nil;
		}
		valueSize = TCArrayElementSize(context->values);
		process = context->process;
		_variableType = [context variableType];
		_integerSign = [context integerSign];
		_operator = op;
		_searchType = TCLastValue;
		compareFunc = [self compareFunction];
		
		regionCount = TCArrayElementCount( context->regions );
		addresses = TCMakeArray( TC_BUFFER_SIZE / sizeof(TCAddress), sizeof(TCAddress) );
		values = TCMakeArray( TC_BUFFER_SIZE / valueSize, valueSize );
		regions = TCMakeArray( 0, sizeof(TCAddress) );
		perRegion = TCMakeArray( 0, sizeof(unsigned) );
		lastAddresses = context->addresses;
		lastValues = context->values;
		lastRegions = context->regions;
		lastPerRegion = context->perRegion;
		addressPtr = TCArrayBytes( addresses );
		valuePtr = TCArrayBytes( values );
		lastAddressPtr = TCArrayBytes( lastAddresses );
		lastValuePtr = TCArrayBytes( lastValues );
		lastRegionPtr = TCArrayBytes( lastRegions );
		lastPerRegionPtr = TCArrayBytes( lastPerRegion );
		
		ChazLog( @"SearchContext: varType=%i, intSign=%i, op=%i", _variableType, _integerSign, _operator );
	}
	return self;
}

- (id)initWithLastContext:(SearchContext *)context searchOperator:(TCSearchOperator)op value:(Variable *)val
{
	unsigned valueSize;
	
	if ( [super init] ) {
		if ( !context || !val || ([val type] != [context variableType]) // and search values can't be bigger than the last time.
			 || (([context variableType] == TCString) && ([val valueSize] > TCArrayElementSize(context->values))) ) {
			[self release];
			return nil;
		}
		value = [val retain];
		valueSize = [value valueSize];
		process = context->process;
		_variableType = [context variableType];
		_integerSign = [context integerSign];
		_operator = op;
		_searchType = TCGivenValue;
		compareFunc = [self compareFunction];
		
		regionCount = TCArrayElementCount( context->regions );
		addresses = TCMakeArray( TC_BUFFER_SIZE / sizeof(TCAddress), sizeof(TCAddress) );
		values = TCMakeArray( TC_BUFFER_SIZE / valueSize, valueSize );
		regions = TCMakeArray( 0, sizeof(TCAddress) );
		perRegion = TCMakeArray( 0, sizeof(unsigned) );
		lastAddresses = context->addresses;
		lastValues = context->values;
		lastRegions = context->regions;
		lastPerRegion = context->perRegion;
		addressPtr = TCArrayBytes( addresses );
		valuePtr = TCArrayBytes( values );
		lastAddressPtr = TCArrayBytes( lastAddresses );
		lastValuePtr = TCArrayBytes( lastValues );
		lastRegionPtr = TCArrayBytes( lastRegions );
		lastPerRegionPtr = TCArrayBytes( lastPerRegion );
		
		ChazLog( @"SearchContext: varType=%i, intSign=%i, op=%i, value=%@", _variableType, _integerSign, _operator, [value stringValue] );
	}
	return self;
}

- (void)dealloc
{
	ChazLog( @"SearchContext %p dealloc", self );
	TCReleaseArray( addresses );
	TCReleaseArray( values );
	TCReleaseArray( regions );
	TCReleaseArray( perRegion );
	
	if ( buffer ) {
		free( buffer );
	}
	[value release];
	
	[super dealloc];
}


#pragma mark Accessors

- (TCVariableType)variableType
{
	return _variableType;
}

- (TCIntegerSign)integerSign
{
	return _integerSign;
}

- (TCSearchOperator)searchOperator
{
	return _operator;
}


- (BOOL (*)(void const *, void const *))compareFunction
{
	// here begins a very pretty collection of switch and if statements. enjoy!
	switch ( _operator ) {
		case TCEqual:
			switch ( _variableType ) {
				case TCFloat: return EqualFloat;
				case TCDouble: return EqualDouble;
			}
			if ( _integerSign == TCSigned ) {
				switch ( _variableType ) {
					case TCInt64: return EqualInt64;
					case TCInt32: return EqualInt32;
					case TCInt16: return EqualInt16;
					case TCInt8: return EqualInt8;
				}
			}
			else {
				switch ( _variableType ) {
					case TCInt64: return EqualUInt64;
					case TCInt32: return EqualUInt32;
					case TCInt16: return EqualUInt16;
					case TCInt8: return EqualUInt8;
				}
			}
			break;
		case TCNotEqual:
			switch ( _variableType ) {
				case TCFloat: return NotEqualFloat;
				case TCDouble: return NotEqualDouble;
			}
			if ( _integerSign == TCSigned ) {
				switch ( _variableType ) {
					case TCInt64: return NotEqualInt64;
					case TCInt32: return NotEqualInt32;
					case TCInt16: return NotEqualInt16;
					case TCInt8: return NotEqualInt8;
				}
			}
			else {
				switch ( _variableType ) {
					case TCInt64: return NotEqualUInt64;
					case TCInt32: return NotEqualUInt32;
					case TCInt16: return NotEqualUInt16;
					case TCInt8: return NotEqualUInt8;
				}
			}
			break;
		case TCLessThan:
			switch ( _variableType ) {
				case TCFloat: return LessThanFloat;
				case TCDouble: return LessThanDouble;
			}
			if ( _integerSign == TCSigned ) {
				switch ( _variableType ) {
					case TCInt64: return LessThanInt64;
					case TCInt32: return LessThanInt32;
					case TCInt16: return LessThanInt16;
					case TCInt8: return LessThanInt8;
				}
			}
			else {
				switch ( _variableType ) {
					case TCInt64: return LessThanUInt64;
					case TCInt32: return LessThanUInt32;
					case TCInt16: return LessThanUInt16;
					case TCInt8: return LessThanUInt8;
				}
			}
			break;
		case TCGreaterThan:
			switch ( _variableType ) {
				case TCFloat: return GreaterThanFloat;
				case TCDouble: return GreaterThanDouble;
			}
			if ( _integerSign == TCSigned ) {
				switch ( _variableType ) {
					case TCInt64: return GreaterThanInt64;
					case TCInt32: return GreaterThanInt32;
					case TCInt16: return GreaterThanInt16;
					case TCInt8: return GreaterThanInt8;
				}
			}
			else {
				switch ( _variableType ) {
					case TCInt64: return GreaterThanUInt64;
					case TCInt32: return GreaterThanUInt32;
					case TCInt16: return GreaterThanUInt16;
					case TCInt8: return GreaterThanUInt8;
				}
			}
			break;
	}
	return NULL;
}

- (int (*)(id, unsigned))iterationFunction
{
	if ( _searchType == TCGivenValue ) {
		if ( !lastAddresses ) {
			if ( _variableType == TCString ) {
				return SearchStringIteration;
			}
			else {
				return SearchIteration;
			}
		}
		else {
			if ( _variableType == TCString ) {
				return SearchStringIterationAgain;
			}
			else {
				return SearchIterationAgain;
			}
		}
	}
	else if ( _searchType == TCLastValue ) {
		if ( _variableType == TCString ) {
			return SearchStringIterationLastValue;
		}
		else {
			return SearchIterationLastValue;
		}
	}
	
	return NULL;
}


@end
