---
name: zustand
description: Zustand state management patterns for React applications. Use when implementing client-side global state, persisted state, or computed values. Lightweight alternative to Redux with minimal boilerplate.
---

# Zustand State Management

> Lightweight, flexible state management for React.

## When NOT to Use

- Server state → Use TanStack Query
- Form state → Use React Hook Form
- URL state → Use router params

## Instructions

### 1. Basic Store

```typescript
// store/useAuthStore.ts
import { create } from 'zustand';

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  
  // Actions
  login: (user: User, token: string) => void;
  logout: () => void;
  updateUser: (updates: Partial<User>) => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: null,
  isAuthenticated: false,

  login: (user, token) => set({
    user,
    token,
    isAuthenticated: true,
  }),

  logout: () => set({
    user: null,
    token: null,
    isAuthenticated: false,
  }),

  updateUser: (updates) => set((state) => ({
    user: state.user ? { ...state.user, ...updates } : null,
  })),
}));
```

### 2. Usage in Components

```tsx
function Header() {
  // ✅ Select only what you need
  const user = useAuthStore((state) => state.user);
  const logout = useAuthStore((state) => state.logout);

  return (
    <header>
      <span>{user?.name}</span>
      <button onClick={logout}>Logout</button>
    </header>
  );
}

// ✅ Multiple selectors
function Profile() {
  const { user, updateUser } = useAuthStore((state) => ({
    user: state.user,
    updateUser: state.updateUser,
  }));
}
```

### 3. Persist Middleware (localStorage)

```typescript
// store/useSettingsStore.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface SettingsState {
  theme: 'light' | 'dark';
  language: 'en' | 'uz' | 'ru';
  sidebarOpen: boolean;
  
  setTheme: (theme: 'light' | 'dark') => void;
  setLanguage: (lang: 'en' | 'uz' | 'ru') => void;
  toggleSidebar: () => void;
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      theme: 'light',
      language: 'en',
      sidebarOpen: true,

      setTheme: (theme) => set({ theme }),
      setLanguage: (language) => set({ language }),
      toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
    }),
    {
      name: 'settings-storage', // localStorage key
      partialize: (state) => ({
        theme: state.theme,
        language: state.language,
        // Don't persist sidebarOpen
      }),
    }
  )
);
```

### 4. Computed Values (Derived State)

```typescript
// store/useCartStore.ts
interface CartState {
  items: CartItem[];
  
  // Actions
  addItem: (item: Product) => void;
  removeItem: (id: string) => void;
  clearCart: () => void;
  
  // Computed (not stored, calculated)
  getTotalItems: () => number;
  getTotalPrice: () => number;
}

export const useCartStore = create<CartState>((set, get) => ({
  items: [],

  addItem: (product) => set((state) => {
    const existing = state.items.find((i) => i.id === product.id);
    if (existing) {
      return {
        items: state.items.map((i) =>
          i.id === product.id ? { ...i, quantity: i.quantity + 1 } : i
        ),
      };
    }
    return { items: [...state.items, { ...product, quantity: 1 }] };
  }),

  removeItem: (id) => set((state) => ({
    items: state.items.filter((i) => i.id !== id),
  })),

  clearCart: () => set({ items: [] }),

  // Computed - use get() to access current state
  getTotalItems: () => get().items.reduce((sum, i) => sum + i.quantity, 0),
  getTotalPrice: () => get().items.reduce((sum, i) => sum + i.price * i.quantity, 0),
}));
```

### 5. Immer Middleware (Immutable Updates)

```typescript
import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';

interface TodoState {
  todos: Todo[];
  addTodo: (text: string) => void;
  toggleTodo: (id: string) => void;
}

export const useTodoStore = create<TodoState>()(
  immer((set) => ({
    todos: [],

    addTodo: (text) => set((state) => {
      // ✅ Mutate directly with immer
      state.todos.push({
        id: crypto.randomUUID(),
        text,
        completed: false,
      });
    }),

    toggleTodo: (id) => set((state) => {
      const todo = state.todos.find((t) => t.id === id);
      if (todo) {
        todo.completed = !todo.completed;
      }
    }),
  }))
);
```

### 6. Slices Pattern (Large Stores)

```typescript
// store/slices/userSlice.ts
export interface UserSlice {
  user: User | null;
  setUser: (user: User) => void;
}

export const createUserSlice = (set: SetState<UserSlice>): UserSlice => ({
  user: null,
  setUser: (user) => set({ user }),
});

// store/slices/cartSlice.ts
export interface CartSlice {
  items: CartItem[];
  addItem: (item: CartItem) => void;
}

export const createCartSlice = (set: SetState<CartSlice>): CartSlice => ({
  items: [],
  addItem: (item) => set((state) => ({ items: [...state.items, item] })),
});

// store/index.ts
type StoreState = UserSlice & CartSlice;

export const useStore = create<StoreState>()((...a) => ({
  ...createUserSlice(...a),
  ...createCartSlice(...a),
}));
```

### 7. Selectors with Shallow Compare

```typescript
import { shallow } from 'zustand/shallow';

// ✅ Prevents unnecessary re-renders
const { user, token } = useAuthStore(
  (state) => ({ user: state.user, token: state.token }),
  shallow
);
```

### 8. Outside React (API calls, etc.)

```typescript
// lib/api.ts
import { useAuthStore } from '@/store/useAuthStore';

export async function fetchWithAuth(url: string) {
  // ✅ Access store outside React
  const token = useAuthStore.getState().token;
  
  return fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
}
```

## Best Practices

| Do | Don't |
|----|-------|
| ✅ One store per domain | ❌ One giant store |
| ✅ Select specific state | ❌ Select entire store |
| ✅ Use persist for settings | ❌ Persist sensitive data |
| ✅ Computed with `get()` | ❌ Store derived state |

## References

- [Zustand Documentation](https://docs.pmnd.rs/zustand)
- [Zustand GitHub](https://github.com/pmndrs/zustand)
