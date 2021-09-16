module lwdr.internal.slinklist;

import std.traits : isDynamicArray, isPointer;

struct SLinkList(T)
{
	private SLinkListNode* root;


}

struct SLinkListNode(T)
{
	private SLinkListNode* next_;
	@property SLinkListNode* next() { return next_; }

	static if(is(T == class) || is(T == interface) || isPointer!T || isDynamicArray!T)
		T item; // store reference
	else
		T* item; // store ptr to target
}