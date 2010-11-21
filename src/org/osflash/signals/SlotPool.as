package org.osflash.signals {
	import flash.display.Shape;
	import flash.events.Event;

	/**
	 * The SlotPool class represents a pool of Slot objects.
	 *
	 * <p>SlotPool is responsible for creating and releasing
	 * Slot objects. A slot object is usually released when
	 * <code>Slot.remove</code> is called. Because of the internal wiring
	 * of signals the SlotPool delays the release of Slot
	 * objects until an <code>Event.EXIT_FRAME</code> event occurs.</p>
	 *
	 * @author Joa Ebert
	 * @private
	 */
	internal final class SlotPool
	{
		{
			// Create a provider for Event.EXIT_FRAME and listen to the event.
			// It is used to collect all dead slots after a frame executed.
			new Shape().addEventListener(Event.EXIT_FRAME, onExitFrame);
		}

		/**
		 * The growth rate of the pool.
		 */
		private static const POOL_GROWTH_RATE: int = 0x10;

		/**
		 * Whether or not if it is allowed to call the constructor of Slot.
		 * @private
		 */
		internal static var constructorAllowed:Boolean;

		/**
		 * The number of available objects in the pool.
		 */
		private static var availableInPool:int;

		/**
		 * A single linked list of Slot objects.
		 */
		private static var pool:Slot;

		/**
		 * A list of slots to release on the EXIT_FRAME event.
		 */
		private static var deadSlots:Slot;

		/**
		 * Returns a Slot object from the pool.
		 *
		 * <p>Creates a series of new Slot objects if the pool is out of object.</p>
		 *
		 * @param listener The listener associated with the slot.
		 * @param once Whether or not the listener should be executed only once.
		 * @param signal The signal associated with the slot.
		 * @param priority The priority of the slot.
		 * @return A slot object.
		 */
		public static function create(listener:Function, once:Boolean = false, signal:ISignal = null, priority:int = 0):Slot
		{
			var pooledObject:Slot;

			if (0 == availableInPool)
			{
				var n:int = POOL_GROWTH_RATE + 1;

				try
				{
					constructorAllowed = true;

					while (--n != 0)
					{
						pooledObject = new Slot();
						pooledObject._nextInPool = pool;
						pool = pooledObject;
					}
				}
				finally
				{
					constructorAllowed = false;
				}

				availableInPool += POOL_GROWTH_RATE;
			}

			pooledObject = pool;
			pool = pooledObject._nextInPool;
			--availableInPool;

			pooledObject.listener = listener;
			pooledObject.once = once;
			pooledObject.priority = priority;
			pooledObject._signal = signal;

			return pooledObject;
		}

		/**
		 * Marks a Slot dead.
		 *
		 * The internal references of the Slot object will be released
		 * when the next Event.EXIT_FRAME event occurs.
		 *
		 * @param slot The slot which is no longer being used.
		 */
		internal static function markDead(slot:Slot):void
		{
			slot._nextInPool = deadSlots;
			deadSlots = slot;
		}

		/**
		 * Listener for native <code>Event.EXIT_FRAME</code>.
		 *
		 * This listener will invoke the <code>releaseDeadSlots</code> method.
		 *
		 * @param event The native event dispatched by the Flash Player.
		 */
		private static function onExitFrame(event:Event):void
		{
			releaseDeadSlots();
		}

		/**
		 * Releases all dead slots and puts them back into the pool.
		 */
		private static function releaseDeadSlots():void
		{
			var nextSlot: Slot = deadSlots;

			while(nextSlot)
			{
				var slot: Slot = nextSlot;
				nextSlot = slot._nextInPool;

				slot.listener = null;
				slot._signal = null;
				slot._nextInPool = pool;
				pool = slot;

				++availableInPool;
			}

			deadSlots = null;
		}
	}
}