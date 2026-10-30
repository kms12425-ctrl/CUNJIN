/**
 * 寸进 · CUNJIN —— 备份文件的选取与读写（唯一接触系统文件 API 的地方）
 *
 * 说明：
 *   · 只用两个系统能力：`picker`（系统文件选择器，无需申请权限）与 `fileIo`（沙箱/URI 读写）；
 *   · 本文件**不**碰 TaskRepository / KV，只负责"拿到文本 / 写出文本"；
 *   · 所有函数失败都返回 undefined / false，不抛异常给 UI 层；
 *   · 这一层无法用本地单测覆盖（依赖系统选择器），纯逻辑已放到 model/ExportDocument.ets。
 *
 * 用到的 API 版本（均 <= compatibleSdkVersion 12）：
 *   picker.DocumentViewPicker / DocumentSaveOptions / DocumentSelectOptions  @since 12
 *   fileIo.openSync / writeSync / readSync / statSync / closeSync            @since 9
 *   util.TextDecoder.create / decodeToString                                  @since 9
 */

import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

/** 弹出"另存为"，返回用户选定的 URI；用户取消时返回 undefined。 */
export async function pickSaveTarget(context: common.Context, fileName: string): Promise<string | undefined> {
  try {
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    const documentPicker = new picker.DocumentViewPicker(context);
    const uris: Array<string> = await documentPicker.save(options);
    if (uris == undefined || uris.length == 0) {
      return undefined;
    }
    return uris[0];
  } catch (error) {
    console.error('BackupFile.pickSaveTarget failed: ' + JSON.stringify(error));
    return undefined;
  }
}

/** 弹出"选择文件"，返回选中的 URI；用户取消时返回 undefined。 */
export async function pickImportSource(context: common.Context): Promise<string | undefined> {
  try {
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    const documentPicker = new picker.DocumentViewPicker(context);
    const uris: Array<string> = await documentPicker.select(options);
    if (uris == undefined || uris.length == 0) {
      return undefined;
    }
    return uris[0];
  } catch (error) {
    console.error('BackupFile.pickImportSource failed: ' + JSON.stringify(error));
    return undefined;
  }
}

/** 把文本写入用户选定的 URI。成功返回 true。 */
export function writeTextToUri(uri: string, text: string): boolean {
  let file: fileIo.File | undefined = undefined;
  try {
    file = fileIo.openSync(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(file.fd, text);
    return true;
  } catch (error) {
    console.error('BackupFile.writeTextToUri failed: ' + JSON.stringify(error));
    return false;
  } finally {
    if (file != undefined) {
      try {
        fileIo.closeSync(file);
      } catch (error) {
        console.error('BackupFile.writeTextToUri close failed: ' + JSON.stringify(error));
      }
    }
  }
}

/** 读取用户选定 URI 的全部文本。失败返回 undefined。 */
export function readTextFromUri(uri: string): string | undefined {
  let file: fileIo.File | undefined = undefined;
  try {
    file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    const stat = fileIo.statSync(file.fd);
    if (stat.size <= 0) {
      return undefined;
    }
    // 备份文件是纯文本 JSON；这里读成字节再由 UTF-8 解码，避免依赖路径形式的 API
    const buffer = new ArrayBuffer(stat.size);
    const readLength = fileIo.readSync(file.fd, buffer);
    if (readLength <= 0) {
      return undefined;
    }
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(new Uint8Array(buffer.slice(0, readLength)));
  } catch (error) {
    console.error('BackupFile.readTextFromUri failed: ' + JSON.stringify(error));
    return undefined;
  } finally {
    if (file != undefined) {
      try {
        fileIo.closeSync(file);
      } catch (error) {
        console.error('BackupFile.readTextFromUri close failed: ' + JSON.stringify(error));
      }
    }
  }
}

/**
 * 把文本写入**应用沙箱**（context.filesDir），无需文件选择器、无需权限。
 * 用于"导入前自动快照"：用户覆盖数据之前，先在本地静默留一份可回溯的副本。
 *
 * 返回写入的绝对路径；失败返回 undefined（调用方据此中止导入）。
 */
export function writeTextToSandbox(context: common.Context, fileName: string, text: string): string | undefined {
  let file: fileIo.File | undefined = undefined;
  try {
    const path = context.filesDir + '/' + fileName;
    file = fileIo.openSync(path,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(file.fd, text);
    return path;
  } catch (error) {
    console.error('BackupFile.writeTextToSandbox failed: ' + JSON.stringify(error));
    return undefined;
  } finally {
    if (file != undefined) {
      try {
        fileIo.closeSync(file);
      } catch (error) {
        console.error('BackupFile.writeTextToSandbox close failed: ' + JSON.stringify(error));
      }
    }
  }
}
