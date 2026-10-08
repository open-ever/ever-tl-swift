// Synthetic schema covering TL grammar and constructor IDs.
// LAYER 17
fixture.scalar value:int = fixture.Scalar;
fixture.empty = fixture.Empty;
fixture.tagged#4a3b2c1d value:bytes = fixture.Tagged;
fixture.zero#00000000 = fixture.Zero;
fixture.choiceNone = fixture.Choice;
fixture.choiceSome value:long = fixture.Choice;
fixture.grid rows:vector<vector<int>> = fixture.Grid;
fixture.options mask:# label:mask.2?string active:mask.31?true = fixture.Options;
fixture.pairs 2 * [ key:int value:bytes ] = fixture.Pairs;
fixture.anonymous # int !X [ bytes ] = fixture.Anonymous;
fixture.template {T:Type} values:vector<!T> = Vector T;
---functions---
fixture.fetch index:int = fixture.Choice;
fixture.invoke {R:Type} query:!R = R;
---types---
fixture.late active:Bool = fixture.Late;
