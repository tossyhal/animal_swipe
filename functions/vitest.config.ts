import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
    // 外部ネットワークへ出る実装を混入させないため、テストは短いタイムアウトで打ち切る。
    testTimeout: 5000,
  },
});
