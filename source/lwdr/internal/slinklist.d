module lwdr.internal.slinklist;

import std.traits : isDynamicArray, isPointer;

/++
For usage within LWDR only. It is a singly-linked-list intended for book keeping memory allocations.
It may grow infinitely, at the cost of undeterministic heap fragmentation.
++/
struct LLLinkedList
{
	private struct Node
	{
		void* item;
		Node* next;
	}

	private Node* root;

	void add(void* ptr) nothrow
	{
		auto n = new Node(ptr);

	}
}