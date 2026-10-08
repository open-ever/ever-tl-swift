// Synthetic schema for generated Swift and wire-format tests.
fixture.record#19ba8f02 index:uint32 enabled:Bool checksum:uint32 = fixture.Record;
fixture.buffer#b61af044 payload:bytes revision:long = fixture.Buffer;
fixture.flags mask:# token:mask.0?uint32 urgent:mask.1?true ready:mask.31?Bool = fixture.Flags;
fixture.shared mask:# left:mask.2?int right:mask.2?int = fixture.Shared;
fixture.vectors bare:(vector fixture.record) boxed:(vector fixture.Record) = fixture.Vectors;
fixture.nested values:(vector (vector int)) = fixture.Nested;
fixture.object value:Object = fixture.Object;
fixture.prefixed value:lengthPrefixedTypedObject = fixture.Prefixed;
fixture.secrets text:secureString bytes:secureBytes = fixture.Secrets;
fixture.keywords self:int class:int = fixture.Keywords;
fixture.marker chain:int epoch:ulong offset:uint digest:int256 = fixture.Marker;
fixture.smallMask bits:uint8 marker:bits.7?fixture.marker = fixture.SmallMask;
fixture.wide maximum:uint64 minimum:int64 extra:uint64 = fixture.Wide;
project.token value:int = project.Token;
projectToken value:bytes = ProjectToken;
payload.entry key:int256 = payload.Entry;
payload.entry version:int32 = model.Entry;
fixture.pong nonce:long = fixture.Pong;
---functions---
fixture.getRecord = fixture.Record;
fixture.invoke {X:Type} query:!X = X;
fixture.lookup mode:# marker:fixture.marker timestamp:mode.1?long = fixture.Marker;
fixture.list marker:fixture.marker mode:# count:# descending:mode.5?true include_hash:mode.6?true = (vector fixture.Record);
fixture.ping nonce:long = fixture.Pong;
