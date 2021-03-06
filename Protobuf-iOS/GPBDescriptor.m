// Protocol Buffers - Google's data interchange format
// Copyright 2008 Google Inc.  All rights reserved.
// https://developers.google.com/protocol-buffers/
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "GPBDescriptor_PackagePrivate.h"

#import <objc/runtime.h>

#import "GPBUtilities_PackagePrivate.h"
#import "GPBWireFormat.h"
#import "GPBMessage_PackagePrivate.h"
#import "Descriptor.pbobjc.h"

// The address of this variable is used as a key for obj_getAssociatedObject.
static const char kTextFormatExtraValueKey = 0;

// Utility function to generate selectors on the fly.
static SEL SelFromStrings(const char *prefix, const char *middle,
                          const char *suffix, BOOL takesArg) {
  if (prefix == NULL && suffix == NULL && !takesArg) {
    return sel_getUid(middle);
  }
  const size_t prefixLen = prefix != NULL ? strlen(prefix) : 0;
  const size_t middleLen = strlen(middle);
  const size_t suffixLen = suffix != NULL ? strlen(suffix) : 0;
  size_t totalLen =
      prefixLen + middleLen + suffixLen + 1;  // include space for null on end.
  if (takesArg) {
    totalLen += 1;
  }
  char buffer[totalLen];
  if (prefix != NULL) {
    memcpy(buffer, prefix, prefixLen);
    memcpy(buffer + prefixLen, middle, middleLen);
    buffer[prefixLen] = (char)toupper(buffer[prefixLen]);
  } else {
    memcpy(buffer, middle, middleLen);
  }
  if (suffix != NULL) {
    memcpy(buffer + prefixLen + middleLen, suffix, suffixLen);
  }
  if (takesArg) {
    buffer[totalLen - 2] = ':';
  }
  // Always null terminate it.
  buffer[totalLen - 1] = 0;

  SEL result = sel_getUid(buffer);
  return result;
}

static NSArray *NewFieldsArrayForHasIndex(int hasIndex,
                                          NSArray *allMessageFields)
    __attribute__((ns_returns_retained));

static NSArray *NewFieldsArrayForHasIndex(int hasIndex,
                                          NSArray *allMessageFields) {
  NSMutableArray *result = [[NSMutableArray alloc] init];
  for (GPBFieldDescriptor *fieldDesc in allMessageFields) {
    if (fieldDesc->description_->hasIndex == hasIndex) {
      [result addObject:fieldDesc];
    }
  }
  return result;
}

@implementation GPBDescriptor {
  Class messageClass_;
  NSArray *enums_;
  GPBFileDescriptor *file_;
  BOOL wireFormat_;
}

@synthesize messageClass = messageClass_;
@synthesize fields = fields_;
@synthesize oneofs = oneofs_;
@synthesize enums = enums_;
@synthesize extensionRanges = extensionRanges_;
@synthesize extensionRangesCount = extensionRangesCount_;
@synthesize file = file_;
@synthesize wireFormat = wireFormat_;

+ (instancetype)
    allocDescriptorForClass:(Class)messageClass
                  rootClass:(Class)rootClass
                       file:(GPBFileDescriptor *)file
                     fields:(GPBMessageFieldDescription *)fieldDescriptions
                 fieldCount:(NSUInteger)fieldCount
                     oneofs:(GPBMessageOneofDescription *)oneofDescriptions
                 oneofCount:(NSUInteger)oneofCount
                      enums:(GPBMessageEnumDescription *)enumDescriptions
                  enumCount:(NSUInteger)enumCount
                     ranges:(const GPBExtensionRange *)ranges
                 rangeCount:(NSUInteger)rangeCount
                storageSize:(size_t)storageSize
                 wireFormat:(BOOL)wireFormat {
  NSMutableArray *fields = nil;
  NSMutableArray *oneofs = nil;
  NSMutableArray *enums = nil;
  NSMutableArray *extensionRanges = nil;
  GPBFileSyntax syntax = file.syntax;
  for (NSUInteger i = 0; i < fieldCount; ++i) {
    if (fields == nil) {
      fields = [[NSMutableArray alloc] initWithCapacity:fieldCount];
    }
    GPBFieldDescriptor *fieldDescriptor = [[GPBFieldDescriptor alloc]
        initWithFieldDescription:&fieldDescriptions[i]
                       rootClass:rootClass
                          syntax:syntax];
    [fields addObject:fieldDescriptor];
    [fieldDescriptor release];
  }
  for (NSUInteger i = 0; i < oneofCount; ++i) {
    if (oneofs == nil) {
      oneofs = [[NSMutableArray alloc] initWithCapacity:oneofCount];
    }
    GPBMessageOneofDescription *oneofDescription = &oneofDescriptions[i];
    NSArray *fieldsForOneof =
        NewFieldsArrayForHasIndex(oneofDescription->index, fields);
    GPBOneofDescriptor *oneofDescriptor =
        [[GPBOneofDescriptor alloc] initWithOneofDescription:oneofDescription
                                                      fields:fieldsForOneof];
    [oneofs addObject:oneofDescriptor];
    [oneofDescriptor release];
    [fieldsForOneof release];
  }
  for (NSUInteger i = 0; i < enumCount; ++i) {
    if (enums == nil) {
      enums = [[NSMutableArray alloc] initWithCapacity:enumCount];
    }
    GPBEnumDescriptor *enumDescriptor =
        enumDescriptions[i].enumDescriptorFunc();
    [enums addObject:enumDescriptor];
  }

  GPBDescriptor *descriptor = [[self alloc] initWithClass:messageClass
                                                     file:file
                                                   fields:fields
                                                   oneofs:oneofs
                                                    enums:enums
                                          extensionRanges:ranges
                                     extensionRangesCount:rangeCount
                                              storageSize:storageSize
                                               wireFormat:wireFormat];
  [fields release];
  [oneofs release];
  [enums release];
  [extensionRanges release];
  return descriptor;
}

+ (instancetype)
    allocDescriptorForClass:(Class)messageClass
                  rootClass:(Class)rootClass
                       file:(GPBFileDescriptor *)file
                     fields:(GPBMessageFieldDescription *)fieldDescriptions
                 fieldCount:(NSUInteger)fieldCount
                     oneofs:(GPBMessageOneofDescription *)oneofDescriptions
                 oneofCount:(NSUInteger)oneofCount
                      enums:(GPBMessageEnumDescription *)enumDescriptions
                  enumCount:(NSUInteger)enumCount
                     ranges:(const GPBExtensionRange *)ranges
                 rangeCount:(NSUInteger)rangeCount
                storageSize:(size_t)storageSize
                 wireFormat:(BOOL)wireFormat
        extraTextFormatInfo:(const char *)extraTextFormatInfo {
  GPBDescriptor *descriptor = [self allocDescriptorForClass:messageClass
                                                  rootClass:rootClass
                                                       file:file
                                                     fields:fieldDescriptions
                                                 fieldCount:fieldCount
                                                     oneofs:oneofDescriptions
                                                 oneofCount:oneofCount
                                                      enums:enumDescriptions
                                                  enumCount:enumCount
                                                     ranges:ranges
                                                 rangeCount:rangeCount
                                                storageSize:storageSize
                                                 wireFormat:wireFormat];
  // Extra info is a compile time option, so skip the work if not needed.
  if (extraTextFormatInfo) {
    NSValue *extraInfoValue = [NSValue valueWithPointer:extraTextFormatInfo];
    for (GPBFieldDescriptor *fieldDescriptor in descriptor->fields_) {
      if (fieldDescriptor->description_->flags & GPBFieldTextFormatNameCustom) {
        objc_setAssociatedObject(fieldDescriptor, &kTextFormatExtraValueKey,
                                 extraInfoValue,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      }
    }
  }
  return descriptor;
}

- (instancetype)initWithClass:(Class)messageClass
                         file:(GPBFileDescriptor *)file
                       fields:(NSArray *)fields
                       oneofs:(NSArray *)oneofs
                        enums:(NSArray *)enums
              extensionRanges:(const GPBExtensionRange *)extensionRanges
         extensionRangesCount:(NSUInteger)extensionRangesCount
                  storageSize:(size_t)storageSize
                   wireFormat:(BOOL)wireFormat {
  if ((self = [super init])) {
    messageClass_ = messageClass;
    file_ = file;
    fields_ = [fields retain];
    oneofs_ = [oneofs retain];
    enums_ = [enums retain];
    extensionRanges_ = extensionRanges;
    extensionRangesCount_ = extensionRangesCount;
    storageSize_ = storageSize;
    wireFormat_ = wireFormat;
  }
  return self;
}

- (void)dealloc {
  [fields_ release];
  [oneofs_ release];
  [enums_ release];
  [super dealloc];
}

- (NSString *)name {
  return NSStringFromClass(messageClass_);
}

- (id)copyWithZone:(NSZone *)zone {
#pragma unused(zone)
  return [self retain];
}

- (GPBFieldDescriptor *)fieldWithNumber:(uint32_t)fieldNumber {
  for (GPBFieldDescriptor *descriptor in fields_) {
    if (GPBFieldNumber(descriptor) == fieldNumber) {
      return descriptor;
    }
  }
  return nil;
}

- (GPBFieldDescriptor *)fieldWithName:(NSString *)name {
  for (GPBFieldDescriptor *descriptor in fields_) {
    if ([descriptor.name isEqual:name]) {
      return descriptor;
    }
  }
  return nil;
}

- (GPBOneofDescriptor *)oneofWithName:(NSString *)name {
  for (GPBOneofDescriptor *descriptor in oneofs_) {
    if ([descriptor.name isEqual:name]) {
      return descriptor;
    }
  }
  return nil;
}

- (GPBEnumDescriptor *)enumWithName:(NSString *)name {
  for (GPBEnumDescriptor *descriptor in enums_) {
    if ([descriptor.name isEqual:name]) {
      return descriptor;
    }
  }
  return nil;
}

@end

@implementation GPBFileDescriptor {
  NSString *package_;
  GPBFileSyntax syntax_;
}

@synthesize package = package_;
@synthesize syntax = syntax_;

- (instancetype)initWithPackage:(NSString *)package
                         syntax:(GPBFileSyntax)syntax {
  self = [super init];
  if (self) {
    package_ = [package copy];
    syntax_ = syntax;
  }
  return self;
}

@end

@implementation GPBOneofDescriptor

@synthesize fields = fields_;

- (instancetype)initWithOneofDescription:
                    (GPBMessageOneofDescription *)oneofDescription
                                  fields:(NSArray *)fields {
  self = [super init];
  if (self) {
    NSAssert(oneofDescription->index < 0, @"Should always be <0");
    oneofDescription_ = oneofDescription;
    fields_ = [fields retain];
    for (GPBFieldDescriptor *fieldDesc in fields) {
      fieldDesc->containingOneof_ = self;
    }

    caseSel_ = SelFromStrings(NULL, oneofDescription->name, "OneOfCase", NO);
  }
  return self;
}

- (void)dealloc {
  [fields_ release];
  [super dealloc];
}

- (NSString *)name {
  return @(oneofDescription_->name);
}

- (GPBFieldDescriptor *)fieldWithNumber:(uint32_t)fieldNumber {
  for (GPBFieldDescriptor *descriptor in fields_) {
    if (GPBFieldNumber(descriptor) == fieldNumber) {
      return descriptor;
    }
  }
  return nil;
}

- (GPBFieldDescriptor *)fieldWithName:(NSString *)name {
  for (GPBFieldDescriptor *descriptor in fields_) {
    if ([descriptor.name isEqual:name]) {
      return descriptor;
    }
  }
  return nil;
}

@end

uint32_t GPBFieldTag(GPBFieldDescriptor *self) {
  GPBMessageFieldDescription *description = self->description_;
  GPBWireFormat format;
  if ((description->flags & GPBFieldMapKeyMask) != 0) {
    // Maps are repeated messages on the wire.
    format = GPBWireFormatForType(GPBDataTypeMessage, NO);
  } else {
    format = GPBWireFormatForType(description->dataType,
                                  ((description->flags & GPBFieldPacked) != 0));
  }
  return GPBWireFormatMakeTag(description->number, format);
}

uint32_t GPBFieldAlternateTag(GPBFieldDescriptor *self) {
  GPBMessageFieldDescription *description = self->description_;
  NSCAssert((description->flags & GPBFieldRepeated) != 0,
            @"Only valid on repeated fields");
  GPBWireFormat format =
      GPBWireFormatForType(description->dataType,
                           ((description->flags & GPBFieldPacked) == 0));
  return GPBWireFormatMakeTag(description->number, format);
}

@implementation GPBFieldDescriptor {
  GPBGenericValue defaultValue_;
  GPBFieldOptions *fieldOptions_;

  // Message ivars
  Class msgClass_;

  // Enum ivars.
  // If protos are generated with GenerateEnumDescriptors on then it will
  // be a enumDescriptor, otherwise it will be a enumVerifier.
  union {
    GPBEnumDescriptor *enumDescriptor_;
    GPBEnumValidationFunc enumVerifier_;
  } enumHandling_;
}

@synthesize fieldOptions = fieldOptions_;
@synthesize msgClass = msgClass_;
@synthesize containingOneof = containingOneof_;

- (instancetype)init {
  // Throw an exception if people attempt to not use the designated initializer.
  self = [super init];
  if (self != nil) {
    [self doesNotRecognizeSelector:_cmd];
    self = nil;
  }
  return self;
}

- (instancetype)initWithFieldDescription:
                    (GPBMessageFieldDescription *)description
                               rootClass:(Class)rootClass
                                  syntax:(GPBFileSyntax)syntax {
  if ((self = [super init])) {
    description_ = description;
    getSel_ = sel_getUid(description->name);
    setSel_ = SelFromStrings("set", description->name, NULL, YES);

    GPBDataType dataType = description->dataType;
    BOOL isMessage = GPBDataTypeIsMessage(dataType);
    BOOL isMapOrArray = GPBFieldIsMapOrArray(self);

    if (isMapOrArray) {
      // map<>/repeated fields get a *Count property (inplace of a has*) to
      // support checking if there are any entries without triggering
      // autocreation.
      hasOrCountSel_ = SelFromStrings(NULL, description->name, "_Count", NO);
    } else {
      // If there is a positive hasIndex, then:
      //   - All fields types for proto2 messages get has* selectors.
      //   - Only message fields for proto3 messages get has* selectors.
      // Note: the positive check is to handle oneOfs, we can't check
      // containingOneof_ because it isn't set until after initialization.
      if ((description->hasIndex >= 0) &&
          (description->hasIndex != GPBNoHasBit) &&
          ((syntax != GPBFileSyntaxProto3) || isMessage)) {
        hasOrCountSel_ = SelFromStrings("has", description->name, NULL, NO);
        setHasSel_ = SelFromStrings("setHas", description->name, NULL, YES);
      }
    }

    // Extra type specific data.
    if (isMessage) {
      const char *className = description->dataTypeSpecific.className;
      msgClass_ = objc_getClass(className);
      NSAssert(msgClass_, @"Class %s not defined", className);
    } else if (dataType == GPBDataTypeEnum) {
      if ((description_->flags & GPBFieldHasEnumDescriptor) != 0) {
        enumHandling_.enumDescriptor_ =
            description->dataTypeSpecific.enumDescFunc();
      } else {
        enumHandling_.enumVerifier_ =
            description->dataTypeSpecific.enumVerifier;
      }
    }

    // Non map<>/repeated fields can have defaults.
    if (!isMapOrArray) {
      defaultValue_ = description->defaultValue;
      if (dataType == GPBDataTypeBytes) {
        // Data stored as a length prefixed (network byte order) c-string in
        // descriptor structure.
        const uint8_t *bytes = (const uint8_t *)defaultValue_.valueData;
        if (bytes) {
          uint32_t length = *((uint32_t *)bytes);
          length = ntohl(length);
          bytes += sizeof(length);
          defaultValue_.valueData =
              [[NSData alloc] initWithBytes:bytes length:length];
        }
      }
    }

    // FieldOptions stored as a length prefixed (network byte order) c-escaped
    // string in descriptor records.
    if (description->fieldOptions) {
      uint8_t *optionsBytes = (uint8_t *)description->fieldOptions;
      uint32_t optionsLength = *((uint32_t *)optionsBytes);
      optionsLength = ntohl(optionsLength);
      if (optionsLength > 0) {
        optionsBytes += sizeof(optionsLength);
        NSData *optionsData = [NSData dataWithBytesNoCopy:optionsBytes
                                                   length:optionsLength
                                             freeWhenDone:NO];
        GPBExtensionRegistry *registry = [rootClass extensionRegistry];
        fieldOptions_ = [[GPBFieldOptions parseFromData:optionsData
                                      extensionRegistry:registry
                                                  error:NULL] retain];
      }
    }
  }
  return self;
}

- (void)dealloc {
  if (description_->dataType == GPBDataTypeBytes &&
      !(description_->flags & GPBFieldRepeated)) {
    [defaultValue_.valueData release];
  }
  [super dealloc];
}

- (GPBDataType)dataType {
  return description_->dataType;
}

- (BOOL)hasDefaultValue {
  return (description_->flags & GPBFieldHasDefaultValue) != 0;
}

- (uint32_t)number {
  return description_->number;
}

- (NSString *)name {
  return @(description_->name);
}

- (BOOL)isRequired {
  return (description_->flags & GPBFieldRequired) != 0;
}

- (BOOL)isOptional {
  return (description_->flags & GPBFieldOptional) != 0;
}

- (GPBFieldType)fieldType {
  GPBFieldFlags flags = description_->flags;
  if ((flags & GPBFieldRepeated) != 0) {
    return GPBFieldTypeRepeated;
  } else if ((flags & GPBFieldMapKeyMask) != 0) {
    return GPBFieldTypeMap;
  } else {
    return GPBFieldTypeSingle;
  }
}

- (GPBDataType)mapKeyDataType {
  switch (description_->flags & GPBFieldMapKeyMask) {
    case GPBFieldMapKeyInt32:
      return GPBDataTypeInt32;
    case GPBFieldMapKeyInt64:
      return GPBDataTypeInt64;
    case GPBFieldMapKeyUInt32:
      return GPBDataTypeUInt32;
    case GPBFieldMapKeyUInt64:
      return GPBDataTypeUInt64;
    case GPBFieldMapKeySInt32:
      return GPBDataTypeSInt32;
    case GPBFieldMapKeySInt64:
      return GPBDataTypeSInt64;
    case GPBFieldMapKeyFixed32:
      return GPBDataTypeFixed32;
    case GPBFieldMapKeyFixed64:
      return GPBDataTypeFixed64;
    case GPBFieldMapKeySFixed32:
      return GPBDataTypeSFixed32;
    case GPBFieldMapKeySFixed64:
      return GPBDataTypeSFixed64;
    case GPBFieldMapKeyBool:
      return GPBDataTypeBool;
    case GPBFieldMapKeyString:
      return GPBDataTypeString;

    default:
      NSAssert(0, @"Not a map type");
      return GPBDataTypeInt32;  // For lack of anything better.
  }
}

- (BOOL)isPackable {
  return (description_->flags & GPBFieldPacked) != 0;
}

- (BOOL)isValidEnumValue:(int32_t)value {
  NSAssert(description_->dataType == GPBDataTypeEnum,
           @"Field Must be of type GPBDataTypeEnum");
  if (description_->flags & GPBFieldHasEnumDescriptor) {
    return enumHandling_.enumDescriptor_.enumVerifier(value);
  } else {
    return enumHandling_.enumVerifier_(value);
  }
}

- (GPBEnumDescriptor *)enumDescriptor {
  if (description_->flags & GPBFieldHasEnumDescriptor) {
    return enumHandling_.enumDescriptor_;
  } else {
    return nil;
  }
}

- (GPBGenericValue)defaultValue {
  // Depends on the fact that defaultValue_ is initialized either to "0/nil" or
  // to an actual defaultValue in our initializer.
  GPBGenericValue value = defaultValue_;

  if (!(description_->flags & GPBFieldRepeated)) {
    // We special handle data and strings. If they are nil, we replace them
    // with empty string/empty data.
    GPBDataType type = description_->dataType;
    if (type == GPBDataTypeBytes && value.valueData == nil) {
      value.valueData = GPBEmptyNSData();
    } else if (type == GPBDataTypeString && value.valueString == nil) {
      value.valueString = @"";
    }
  }
  return value;
}

- (NSString *)textFormatName {
  if ((description_->flags & GPBFieldTextFormatNameCustom) != 0) {
    NSValue *extraInfoValue =
        objc_getAssociatedObject(self, &kTextFormatExtraValueKey);
    // Support can be left out at generation time.
    if (!extraInfoValue) {
      return nil;
    }
    const uint8_t *extraTextFormatInfo = [extraInfoValue pointerValue];
    return GPBDecodeTextFormatName(extraTextFormatInfo, GPBFieldNumber(self),
                                   self.name);
  }

  // The logic here has to match SetCommonFieldVariables() from
  // objectivec_field.cc in the proto compiler.
  NSString *name = self.name;
  NSUInteger len = [name length];

  // Remove the "_p" added to reserved names.
  if ([name hasSuffix:@"_p"]) {
    name = [name substringToIndex:(len - 2)];
    len = [name length];
  }

  // Remove "Array" from the end for repeated fields.
  if (((description_->flags & GPBFieldRepeated) != 0) &&
      [name hasSuffix:@"Array"]) {
    name = [name substringToIndex:(len - 5)];
    len = [name length];
  }

  // Groups vs. other fields.
  if (description_->dataType == GPBDataTypeGroup) {
    // Just capitalize the first letter.
    unichar firstChar = [name characterAtIndex:0];
    if (firstChar >= 'a' && firstChar <= 'z') {
      NSString *firstCharString =
          [NSString stringWithFormat:@"%C", (unichar)(firstChar - 'a' + 'A')];
      NSString *result =
          [name stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                        withString:firstCharString];
      return result;
    }
    return name;

  } else {
    // Undo the CamelCase.
    NSMutableString *result = [NSMutableString stringWithCapacity:len];
    for (NSUInteger i = 0; i < len; i++) {
      unichar c = [name characterAtIndex:i];
      if (c >= 'A' && c <= 'Z') {
        if (i > 0) {
          [result appendFormat:@"_%C", (unichar)(c - 'A' + 'a')];
        } else {
          [result appendFormat:@"%C", c];
        }
      } else {
        [result appendFormat:@"%C", c];
      }
    }
    return result;
  }
}

@end

@implementation GPBEnumDescriptor {
  NSString *name_;
  GPBMessageEnumValueDescription *valueDescriptions_;
  NSUInteger valueDescriptionsCount_;
  GPBEnumValidationFunc enumVerifier_;
  const uint8_t *extraTextFormatInfo_;
}

@synthesize name = name_;
@synthesize enumVerifier = enumVerifier_;

+ (instancetype)
    allocDescriptorForName:(NSString *)name
                    values:(GPBMessageEnumValueDescription *)valueDescriptions
                valueCount:(NSUInteger)valueCount
              enumVerifier:(GPBEnumValidationFunc)enumVerifier {
  GPBEnumDescriptor *descriptor = [[self alloc] initWithName:name
                                                      values:valueDescriptions
                                                  valueCount:valueCount
                                                enumVerifier:enumVerifier];
  return descriptor;
}

+ (instancetype)
    allocDescriptorForName:(NSString *)name
                    values:(GPBMessageEnumValueDescription *)valueDescriptions
                valueCount:(NSUInteger)valueCount
              enumVerifier:(GPBEnumValidationFunc)enumVerifier
       extraTextFormatInfo:(const char *)extraTextFormatInfo {
  // Call the common case.
  GPBEnumDescriptor *descriptor = [self allocDescriptorForName:name
                                                        values:valueDescriptions
                                                    valueCount:valueCount
                                                  enumVerifier:enumVerifier];
  // Set the extra info.
  descriptor->extraTextFormatInfo_ = (const uint8_t *)extraTextFormatInfo;
  return descriptor;
}

- (instancetype)initWithName:(NSString *)name
                      values:(GPBMessageEnumValueDescription *)valueDescriptions
                  valueCount:(NSUInteger)valueCount
                enumVerifier:(GPBEnumValidationFunc)enumVerifier {
  if ((self = [super init])) {
    name_ = [name copy];
    valueDescriptions_ = valueDescriptions;
    valueDescriptionsCount_ = valueCount;
    enumVerifier_ = enumVerifier;
  }
  return self;
}

- (NSString *)enumNameForValue:(int32_t)number {
  for (NSUInteger i = 0; i < valueDescriptionsCount_; ++i) {
    GPBMessageEnumValueDescription *scan = &valueDescriptions_[i];
    if ((scan->number == number) && (scan->name != NULL)) {
      NSString *fullName =
          [NSString stringWithFormat:@"%@_%s", name_, scan->name];
      return fullName;
    }
  }
  return nil;
}

- (BOOL)getValue:(int32_t *)outValue forEnumName:(NSString *)name {
  // Must have the prefix.
  NSUInteger prefixLen = name_.length + 1;
  if ((name.length <= prefixLen) || ![name hasPrefix:name_] ||
      ([name characterAtIndex:prefixLen - 1] != '_')) {
    return NO;
  }

  // Skip over the prefix.
  const char *nameAsCStr = [name UTF8String];
  nameAsCStr += prefixLen;

  // Find it.
  for (NSUInteger i = 0; i < valueDescriptionsCount_; ++i) {
    GPBMessageEnumValueDescription *scan = &valueDescriptions_[i];
    if ((scan->name != NULL) && (strcmp(nameAsCStr, scan->name) == 0)) {
      if (outValue) {
        *outValue = scan->number;
      }
      return YES;
    }
  }
  return NO;
}

- (void)dealloc {
  [name_ release];
  [super dealloc];
}

- (NSString *)textFormatNameForValue:(int32_t)number {
  // Find the EnumValue descriptor and its index.
  GPBMessageEnumValueDescription *valueDescriptor = NULL;
  NSUInteger valueDescriptorIndex;
  for (valueDescriptorIndex = 0; valueDescriptorIndex < valueDescriptionsCount_;
       ++valueDescriptorIndex) {
    GPBMessageEnumValueDescription *scan =
        &valueDescriptions_[valueDescriptorIndex];
    if (scan->number == number) {
      valueDescriptor = scan;
      break;
    }
  }

  // If we didn't find it, or names were disable at proto compile time, nothing
  // we can do.
  if (!valueDescriptor || !valueDescriptor->name) {
    return nil;
  }

  NSString *result = nil;
  // Naming adds an underscore between enum name and value name, skip that also.
  NSString *shortName = @(valueDescriptor->name);

  // See if it is in the map of special format handling.
  if (extraTextFormatInfo_) {
    result = GPBDecodeTextFormatName(extraTextFormatInfo_,
                                     (int32_t)valueDescriptorIndex, shortName);
  }
  // Logic here needs to match what objectivec_enum.cc does in the proto
  // compiler.
  if (result == nil) {
    NSUInteger len = [shortName length];
    NSMutableString *worker = [NSMutableString stringWithCapacity:len];
    for (NSUInteger i = 0; i < len; i++) {
      unichar c = [shortName characterAtIndex:i];
      if (i > 0 && c >= 'A' && c <= 'Z') {
        [worker appendString:@"_"];
      }
      [worker appendFormat:@"%c", toupper((char)c)];
    }
    result = worker;
  }
  return result;
}

@end

@implementation GPBExtensionDescriptor {
  GPBGenericValue defaultValue_;
}

@synthesize containingMessageClass = containingMessageClass_;

- (instancetype)initWithExtensionDescription:
        (GPBExtensionDescription *)description {
  if ((self = [super init])) {
    description_ = description;

#if DEBUG
    const char *className = description->messageOrGroupClassName;
    if (className) {
      NSAssert(objc_lookUpClass(className) != Nil,
               @"Class %s not defined", className);
    }
#endif

    if (description->extendedClass) {
      Class containingClass = objc_lookUpClass(description->extendedClass);
      NSAssert(containingClass, @"Class %s not defined",
               description->extendedClass);
      containingMessageClass_ = containingClass;
    }

    GPBDataType type = description_->dataType;
    if (type == GPBDataTypeBytes) {
      // Data stored as a length prefixed c-string in descriptor records.
      const uint8_t *bytes =
          (const uint8_t *)description->defaultValue.valueData;
      if (bytes) {
        uint32_t length = *((uint32_t *)bytes);
        // The length is stored in network byte order.
        length = ntohl(length);
        bytes += sizeof(length);
        defaultValue_.valueData =
            [[NSData alloc] initWithBytes:bytes length:length];
      }
    } else if (type == GPBDataTypeMessage || type == GPBDataTypeGroup) {
      // The default is looked up in -defaultValue instead since extensions
      // aren't common, we avoid the hit startup hit and it avoid initialization
      // order issues.
    } else {
      defaultValue_ = description->defaultValue;
    }
  }
  return self;
}

- (void)dealloc {
  if ((description_->dataType == GPBDataTypeBytes) &&
      !GPBExtensionIsRepeated(description_)) {
    [defaultValue_.valueData release];
  }
  [super dealloc];
}

- (instancetype)copyWithZone:(NSZone *)zone {
#pragma unused(zone)
  // Immutable.
  return [self retain];
}

- (NSString *)singletonName {
  return @(description_->singletonName);
}

- (const char *)singletonNameC {
  return description_->singletonName;
}

- (uint32_t)fieldNumber {
  return description_->fieldNumber;
}

- (GPBDataType)dataType {
  return description_->dataType;
}

- (GPBWireFormat)wireType {
  return GPBWireFormatForType(description_->dataType,
                              GPBExtensionIsPacked(description_));
}

- (GPBWireFormat)alternateWireType {
  NSAssert(GPBExtensionIsRepeated(description_),
           @"Only valid on repeated extensions");
  return GPBWireFormatForType(description_->dataType,
                              !GPBExtensionIsPacked(description_));
}

- (BOOL)isRepeated {
  return GPBExtensionIsRepeated(description_);
}

- (BOOL)isMap {
  return (description_->options & GPBFieldMapKeyMask) != 0;
}

- (BOOL)isPackable {
  return GPBExtensionIsPacked(description_);
}

- (Class)msgClass {
  return objc_getClass(description_->messageOrGroupClassName);
}

- (GPBEnumDescriptor *)enumDescriptor {
  if (description_->dataType == GPBDataTypeEnum) {
    GPBEnumDescriptor *enumDescriptor = description_->enumDescriptorFunc();
    return enumDescriptor;
  }
  return nil;
}

- (id)defaultValue {
  if (GPBExtensionIsRepeated(description_)) {
    return nil;
  }

  switch (description_->dataType) {
    case GPBDataTypeBool:
      return @(defaultValue_.valueBool);
    case GPBDataTypeFloat:
      return @(defaultValue_.valueFloat);
    case GPBDataTypeDouble:
      return @(defaultValue_.valueDouble);
    case GPBDataTypeInt32:
    case GPBDataTypeSInt32:
    case GPBDataTypeEnum:
    case GPBDataTypeSFixed32:
      return @(defaultValue_.valueInt32);
    case GPBDataTypeInt64:
    case GPBDataTypeSInt64:
    case GPBDataTypeSFixed64:
      return @(defaultValue_.valueInt64);
    case GPBDataTypeUInt32:
    case GPBDataTypeFixed32:
      return @(defaultValue_.valueUInt32);
    case GPBDataTypeUInt64:
    case GPBDataTypeFixed64:
      return @(defaultValue_.valueUInt64);
    case GPBDataTypeBytes:
      // Like message fields, the default is zero length data.
      return (defaultValue_.valueData ? defaultValue_.valueData
                                      : GPBEmptyNSData());
    case GPBDataTypeString:
      // Like message fields, the default is zero length string.
      return (defaultValue_.valueString ? defaultValue_.valueString : @"");
    case GPBDataTypeGroup:
    case GPBDataTypeMessage:
      return nil;
  }
}

- (NSComparisonResult)compareByFieldNumber:(GPBExtensionDescriptor *)other {
  int32_t selfNumber = description_->fieldNumber;
  int32_t otherNumber = other->description_->fieldNumber;
  if (selfNumber < otherNumber) {
    return NSOrderedAscending;
  } else if (selfNumber == otherNumber) {
    return NSOrderedSame;
  } else {
    return NSOrderedDescending;
  }
}

@end
