/**
 * 寸进 · CUNJIN —— 可等待、可重试的 KV 存储封装
 *
 * 相比旧版 KVManagerTools 的根本区别：
 * 1. 不再在**模块导入时**初始化。初始化由 EntryAbility.onCreate 显式传入 Context 触发。
 * 2. 初始化是 Promise，可等待、幂等、失败可重试（失败后清除缓存，下次调用重新初始化）。
 * 3. 读写都走 Promise，调用方可以 await，因此不存在"存储没准备好就静默跳过写入"的路径。
 * 4. 所有异常都会被记录并向上抛出，由 Repository 统一处理，不再静默吞掉。
 */

import { distributedKVStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'Cunjin.Storage';
const BUNDLE_NAME: string = 'com.junhao.cunjin';
const STORE_NAME: string = 'junhao_store';

export class Storage {
  private static ready: Promise<void> | null = null;
  private static store: distributedKVStore.SingleKVStore | null = null;
  private static failure: string = '';

  /** 幂等初始化。失败后可再次调用重试。 */
  static init(context: common.Context): Promise<void> {
    if (Storage.ready === null) {
      const attempt = Storage.doInit(context);
      Storage.ready = attempt;
      // 失败后清空缓存，允许下一次调用重新初始化
      attempt.catch(() => {
        if (Storage.ready === attempt) {
          Storage.ready = null;
        }
      });
    }
    return Storage.ready as Promise<void>;
  }

  private static async doInit(context: common.Context): Promise<void> {
    const config: distributedKVStore.KVManagerConfig = {
      context: context,
      bundleName: BUNDLE_NAME
    };
    const options: distributedKVStore.Options = {
      createIfMissing: true,
      encrypt: false,
      backup: false,
      autoSync: false,
      kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
      securityLevel: distributedKVStore.SecurityLevel.S1
    };
    try {
      const manager = distributedKVStore.createKVManager(config);
      const store = await manager.getKVStore<distributedKVStore.SingleKVStore>(STORE_NAME, options);
      Storage.store = store;
      Storage.failure = '';
      hilog.info(DOMAIN, TAG, '%{public}s', 'KV store ready: ' + STORE_NAME);
    } catch (error) {
      const err = error as BusinessError;
      Storage.failure = 'init failed: code=' + err.code + ' message=' + err.message;
      hilog.error(DOMAIN, TAG, '%{public}s', Storage.failure);
      throw new Error(Storage.failure);
    }
  }

  static isReady(): boolean {
    return Storage.store !== null;
  }

  static lastFailure(): string {
    return Storage.failure;
  }

  /**
   * 读取原始值。键不存在返回 undefined（区别于旧版返回 "no" 哨兵）。
   * 调用方必须先 await，因此不会读到"尚未就绪"的状态。
   */
  static async get(key: string): Promise<string | undefined> {
    if (Storage.store === null) {
      throw new Error('Storage.get 调用时存储尚未初始化: ' + key);
    }
    try {
      const value = await (Storage.store as distributedKVStore.SingleKVStore).get(key);
      if (typeof value === 'string') {
        return value;
      }
      if (typeof value === 'number' || typeof value === 'boolean') {
        return value.toString();
      }
      return undefined;
    } catch (error) {
      // 键不存在时底层可能抛错，这里统一视为"没有值"，但把原因记下来
      const err = error as BusinessError;
      hilog.warn(DOMAIN, TAG, '%{public}s',
        'get(' + key + ') failed: code=' + err.code + ' message=' + err.message);
      return undefined;
    }
  }

  /** 写入字符串值。失败会抛出，绝不静默丢弃。 */
  static async put(key: string, value: string): Promise<void> {
    if (Storage.store === null) {
      throw new Error('Storage.put 调用时存储尚未初始化: ' + key);
    }
    try {
      await (Storage.store as distributedKVStore.SingleKVStore).put(key, value);
    } catch (error) {
      const err = error as BusinessError;
      const message = 'put(' + key + ') failed: code=' + err.code + ' message=' + err.message;
      hilog.error(DOMAIN, TAG, '%{public}s', message);
      throw new Error(message);
    }
  }
}
