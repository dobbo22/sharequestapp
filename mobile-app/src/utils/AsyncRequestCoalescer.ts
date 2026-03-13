// AsyncRequestCoalescer.ts
// Coalesce async requests by key (deduplicate in-flight requests)

export type AsyncFn<K, V> = (key: K) => Promise<V>;

export class AsyncRequestCoalescer<K, V> {
  private inFlight: Map<K, Promise<V>> = new Map();

  constructor(private fn: AsyncFn<K, V>) {}

  async get(key: K): Promise<V> {
    if (this.inFlight.has(key)) {
      return this.inFlight.get(key)!;
    }
    const promise = this.fn(key)
      .finally(() => {
        this.inFlight.delete(key);
      });
    this.inFlight.set(key, promise);
    return promise;
  }
}

// Example usage:
// import { AsyncRequestCoalescer } from './AsyncRequestCoalescer';
// const fetchUser = async (id: string) => fetch(`/api/user/${id}`).then(res => res.json());
// const userCoalescer = new AsyncRequestCoalescer(fetchUser);
// userCoalescer.get('123').then(console.log);
// userCoalescer.get('123').then(console.log); // Shares the same promise
