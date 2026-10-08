// Synthetic schema for deterministic Swift generation.
model.entry version:int digest:int256 = model.Entry;
model.absent = model.State;
model.present entry:model.entry = model.State;
model.batch bare:(vector model.entry) boxed:(vector model.Entry) = model.Batch;
model.tree mask:# children:mask.0?(vector model.Tree) = model.Tree;
model.small bits:uint8 payload:bits.7?bytes = model.Small;
model.token value:int = model.Token;
modelToken value:long = ModelToken;
model.receipt value:int = model.receipt;
---functions---
model.fetch version:int = model.Entry;
model.getReceipt = model.Receipt;
model.invoke {X:Type} query:!X = X;
