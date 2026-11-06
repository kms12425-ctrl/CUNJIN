import display from '@ohos.display';
import { SegmentButtonOptions } from '@ohos.arkui.advanced.SegmentButton';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { systemDateTime } from '@kit.BasicServicesKit';
import { TaskRepository } from '../repository/TaskRepository';
import {
  SCHEMA_VERSION, CardArrays, CardSettings, TaskCardData, WorkState, createDefaultSettings
} from '../model/TaskCardData';
import {
  applyPunch, clampDayIndex, createPunchCard, creditDone, fromCards, relativeDaysPassed, toCards,
  moveCardToIndex, swapCardPositions, moveIdToIndex, swapIdPositions, appendPlaceholderId, removeIdAt,
  shiftIndexAfterDelete
} from '../model/CardMapper';
import {
  connectedDate, doneValue, donePercentage, timeLeftPercentage, averageDailyWorkLeftForDisplay,
  averageDailyWork, todayBlockIndex, dateOfChosen
} from '../model/CardQueries';
import {
  hoursOnDay, hoursInRecentDays, currentStreak, totalHours, activeDayCount, forecastCard, CardForecast
} from '../model/CardStats';
import { deserializeSettings } from '../model/CardCodec';
import {
  buildExportText, parseExportText, exportFileName, preImportFileName, ExportParseResult
} from '../model/ExportDocument';
import {
  pickSaveTarget, pickImportSource, writeTextToUri, readTextFromUri, writeTextToSandbox
} from '../repository/BackupFile';
// 组件拆分：以下结构原本与本页同处一个文件，现已原样搬到独立文件（布局/尺寸/动效未改动）
import { StatsPanel } from '../components/StatsPanel';
import { DayNotePanel } from '../components/DayNotePanel';
import { JunHaoBlock } from '../components/CardBlock';
import { JunHaoDataBoard } from '../components/DataBoardChart';
import { JunHaoSymbolButton } from '../components/atoms/SymbolButton';
import { JunHaoLeftTitle } from '../components/atoms/LeftTitle';
import { JunHaoRightExplanation } from '../components/atoms/RightExplanation';
import { JunHaoTextArea } from '../components/atoms/TextArea';
import { Backdrop } from '../components/Backdrop';
import { HeroHeader } from '../components/HeroHeader';
import { StartupCover } from '../components/StartupCover';
import { SettingsPanel } from '../components/SettingsPanel';
import { AddCardPanel } from '../components/AddCardPanel';
import { CardInfoBlock } from '../components/CardInfoBlock';
import { DoneGraph } from '../components/DoneGraph';
import { TimeGraph } from '../components/TimeGraph';
import { SubmittedBlock } from '../components/SubmittedBlock';
import { EstimatingBlock } from '../components/EstimatingBlock';
import { EditCard } from '../components/EditCard';
import { ManagePanel } from '../components/ManagePanel';
import { CardDetailSpacer } from '../components/CardDetailSpacer';
import { animateParam } from '../design/JunHaoUi';
import { formatElapsedClock } from '../model/TimeFormat';

@Entry
@Component
struct Index {
  @State ENVIRONMENT_screen_width: number = display.getDefaultDisplaySync().width
  @State ENVIRONMENT_screen_height: number = display.getDefaultDisplaySync().height
  @StorageProp('currentColorMode') @Watch('onColorModeChange') ENVIRONMENT_current_color_mode: number = 0
  @StorageProp('currentDirection') @Watch('onDirectionChange') ENVIRONMENT_current_direction: number = 1
  @State ENVIRONMENT_current_timestamp: number = systemDateTime.getTime()
  @State STATUS_top_card_settings_is_open: boolean = false
  @State STATUS_top_card_add_is_open: boolean = false
  // 新建卡片失败提示弹窗：失败原因用资源 key 表示（重名 / 空名字），
  // 由 CARD_add_card() 在 return false 前填入，弹窗据此显示对应标题与正文。
  @State STATUS_add_failed_warning_is_open: boolean = false
  @State STATUS_add_failed_title: string = "app.string.Add_Card_Duplicate_Title"
  @State STATUS_add_failed_message: string = "app.string.Add_Card_Duplicate_Message"
  @State STATUS_current_time_period: string = "Morning"
  @State @Watch('onCardExpand') STATUS_card_expanding: number = -1
  @State STATUS_card_index_of_last_expanded: number = -1
  @State DESIGN_use_backdrop: boolean = false;
  @State DESIGN_color_scheme_light_default: string = "#5D1E3928,#FFC1CFC6,#FFFFFFFF,#FF334C42,#B0263F0F,#FFE3ECE7"
  @State DESIGN_color_scheme_dark_default: string = "#B3243930,#FF1F2B26,#FFC1CFC6,#FFC1CFC6,#80090E0B,#FF3F5A4E"
  @State DESIGN_color_scheme_light: string[] = this.DESIGN_color_scheme_light_default.split(",")
  @State DESIGN_color_scheme_dark: string[] = this.DESIGN_color_scheme_dark_default.split(",")
  @State DESIGN_color_scheme: string[] = []
  @State DESIGN_cards_blur_radius: number = 25
  @State DESIGN_min_card_size: number = 450

  @State DESIGN_font_color: string = this.DESIGN_color_scheme[2]
  @State DESIGN_block_background_color: string = this.DESIGN_color_scheme[4]
  @State UI_is_first_open: boolean = true
  @State UI_waterFlow_Layout: string = ""
  @State UI_waterFlow_Columns: number = 0
  @State UI_waterFlow_firstScroll: boolean = true
  @State UI_Title_top_margin: number = 90
  @State UI_Title_font_zoom: number = 1.00
  @State UI_Title_y_offset: number = 50
  @State UI_Title_opacity: number = 0
  @State UI_subTitle_y_offset: number = 50
  @State UI_subTitle_opacity: number = 0
  @State UI_top_card_offset: number = 50
  @State UI_top_card_opacity: number = 0
  @State UI_top_card_height: number = 170
  @State UI_top_card_greetings_address: string = "app.string.Greetings_Morning"
  @State UI_status_card_offset: number = 50
  @State UI_status_card_opacity: number = 0
  @State @Watch('onChangeBackground') UI_backdrop_choose: number[] = [0]
  // if UI_backdrop_choose == [0] then use Pure Color as background
  @State UI_backdrop_segment_button_options: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: $r("app.string.Settings_Content_Background_Color") },
      { text: $r("app.string.Settings_Content_Background_Image") }],
    fontColor: this.DESIGN_font_color,
    selectedFontColor: this.DESIGN_block_background_color,
    fontWeight: FontWeight.Medium, // backgroundColor: this.Color_scheme[0],
    selectedFontWeight: FontWeight.Bolder,
    selectedBackgroundColor: this.DESIGN_font_color
  })
  @State UI_card_expanded_remaining_days: number = 0
  @State UI_card_expanded_slogan_of_time: string = "Card_Progress_Desc_Time_"
  @State UI_card_expanded_viewing_detail_of_block_index: number = 0
  @State UI_start_up_cover_continue_opacity: number = 1
  @State SETTINGS_color_scheme_edit_light: string = this.DESIGN_color_scheme_light.toString()
  @State SETTINGS_color_scheme_edit_dark: string = this.DESIGN_color_scheme_dark.toString()
  @State SETTINGS_reset_design_confirm: number = 0
  @State ADD_name: string = ""
  @State ADD_description: string = ""
  @State ADD_length: number = 200
  @State ADD_length_description: string = "app.string.Add_Length_Notice_Short"
  @State ADD_time_limit: number = 21
  @State ADD_time_limit_unit_or_description: string = "app.string.Add_Day"
  @State ADD_value_target: number = 12
  @State ADD_value_target_unit_or_description: string = "app.string.Add_Value_Unit_Hour"
  @State EDIT_name: string = ""
  @State EDIT_description: string = ""
  @State EDIT_length: number = 200
  @State EDIT_length_description: string = "app.string.Add_Length_Notice_Short"
  @State EDIT_delete_card_confirm: boolean = false
  /** 归档的二次确认位（与删除同款：第一次点击只翻它，第二次才真正归档） */
  @State EDIT_archive_confirm: boolean = false
  @State DATA_app_open_time: number = 0
  @State DATA_cards_name: string[] = []
  @State DATA_cards_desc: string[] = []
  @State DATA_cards_length: number[] = []
  @State DATA_cards_time_limit: number[] = []
  @State DATA_cards_target: number[] = []
  @State DATA_cards_done: number[] = []
  @State DATA_cards_start: number[] = []
  @State DATA_cards_end: number[] = []
  @State DATA_cards_punch_card: number[][] = []
  /** 每日备注，与 DATA_cards_punch_card 同形（schema 5） */
  @State DATA_cards_note: string[][] = []
  @State DATA_work_working_card_name: string = ""
  @State DATA_work_start: number = 0
  @State DATA_work_last_end: number = systemDateTime.getTime()
  scroller_card_expand: Scroller = new Scroller()
  scroller_main: Scroller = new Scroller()

  // ---- 升级新增：非响应式内部字段（不参与渲染，故不使用 @State，避免无谓刷新） ----
  private tickerId: number = -1
  private cardIds: string[] = []
  /**
   * 是否已归档，与其它卡片数组按**下标**一一对应（@State：归档后要立刻隐藏/重绘）。
   *
   * 早期版本用"已归档 id 列表"旁表 + 按 id 反查，结果新建卡片的占位 id（空串）
   * 与 cardIds 重建之间存在窗口期，会把新卡片误判成已归档（标题被划线）。
   * 改成与 notes/punchCard 同一套按下标投影后，这个 bug 从结构上消失：
   * 新增 push(false)、删除 splice、重排走 CardArrays 的布尔位移辅助函数。
   */
  @State DATA_cards_archived: boolean[] = []
  private dataLoaded: boolean = false
  private loadingInFlight: boolean = false
  private appOpenCounted: boolean = false
  private migrationWarnings: string[] = []
  private applyingSettings: boolean = false

  aboutToAppear(): void {
    // 只创建一个有效定时器：重复进入页面不会叠加
    if (this.tickerId == -1) {
      console.log("Timer: Start!")
      this.tickerId = setInterval(() => {
        this.UTIL_refresh_current_time_stamp()
      }, 1000);
    }
    // 尽早开始加载，缩短"数据未就绪"的窗口
    this.loadAllData()
  }

  aboutToDisappear(): void {
    // 配对清理：否则页面销毁后定时器仍在运行，并持久持有整个组件树
    if (this.tickerId != -1) {
      clearInterval(this.tickerId)
      this.tickerId = -1
      console.log("Timer: Stop!")
    }
  }

  onPageHide(): void {
    // 页面不可见时尽量把排队中的写入落盘。
    // 否则"刚换位就切后台、进程随即被杀"会丢掉最后一次改动。
    TaskRepository.flushPendingWrites()
  }

  onPageShow() {
    console.log("onPageShow")
    // 每次显示都刷新时间戳：避免定时器被清理/冻结后仍用旧值计算时长
    this.UTIL_refresh_current_time_stamp()
    this.loadAllData()
  }

  /** 外观默认值（与原 DESIGN_color_scheme_*_default 保持一致） */
  private settingsDefaults(): CardSettings {
    return createDefaultSettings(this.DESIGN_color_scheme_light_default.split(","),
      this.DESIGN_color_scheme_dark_default.split(","), 25, 450)
  }

  /**
   * 单一加载入口。
   * 替代旧版 12 个互不等待的 getValueOfKey().then()：一次 await 串行完成
   * 迁移 -> 卡片 -> 设置 -> 计时状态，顺序确定、重复调用结果幂等。
   */
  private async loadAllData(): Promise<void> {
    if (this.loadingInFlight) {
      return
    }
    this.loadingInFlight = true
    try {
      const defaults = this.settingsDefaults()

      // 先等待上一次尚未落盘的写入完成，
      // 避免"刚改完还没落盘、后台切回前台重新加载却读到旧值"的竞态。
      await TaskRepository.flushPendingWrites()

      const outcome = await TaskRepository.ensureLegacyMigrated(defaults)
      this.migrationWarnings = outcome.warnings
      if (outcome.warnings.length > 0) {
        console.warn('Migration(' + outcome.reason + ') warnings: ' + outcome.warnings.join(' | '))
      }

      const cards = await TaskRepository.loadCards()
      this.applyCards(cards)
      const storedSettings = await TaskRepository.loadSettings(defaults)
      const settings = storedSettings === undefined ? defaults : storedSettings
      this.applySettings(settings)

      const work = await TaskRepository.loadWorkState()
      this.applyWorkState(work)

      if (!this.appOpenCounted) {
        this.appOpenCounted = true
        this.DATA_app_open_time = this.DATA_app_open_time + 1
        await TaskRepository.saveSettings(this.collectSettings())
      }

      // 与原行为一致：全新安装的首次会话显示 Welcome，之后（以及升级用户）显示问候语
      this.UI_is_first_open = outcome.firstRun
      this.dataLoaded = true
      this.DESIGN_update_key_colors()
      this.UI_set_SegmentButton_Options()
      this.UI_set_waterFlow_layout()
    } catch (error) {
      const err = error as Error
      console.error('loadAllData failed: ' + err.message +
        ' / storage=' + TaskRepository.lastFailure())
    } finally {
      this.loadingInFlight = false
    }
  }

  /** 对象模型 -> 数组视图。整体赋值，保证刷新且不残留上一次的数据。 */
  private applyCards(cards: TaskCardData[]): void {
    const arrays: CardArrays = fromCards(cards)
    this.applyArrays(arrays)

    this.cardIds = []
    for (let i = 0; i < cards.length; i++) {
      this.cardIds.push(cards[i].id)
    }
    if (this.STATUS_card_expanding >= cards.length) {
      this.STATUS_card_expanding = -1
    }
    if (this.STATUS_card_index_of_last_expanded >= cards.length) {
      this.STATUS_card_index_of_last_expanded = -1
    }
  }

  /**
   * 把 9 个平行数组整体赋回 @State。
   * 这里是「数组投影」的唯一写入点：加载和换位都走它，
   * 避免出现两处赋值逻辑不一致。
   */
  private applyArrays(arrays: CardArrays): void {
    this.DATA_cards_name = arrays.name
    this.DATA_cards_desc = arrays.desc
    this.DATA_cards_length = arrays.length
    this.DATA_cards_time_limit = arrays.timeLimitDays
    this.DATA_cards_target = arrays.targetHours
    this.DATA_cards_done = arrays.doneHours
    this.DATA_cards_start = arrays.startAt
    this.DATA_cards_end = arrays.endAt
    this.DATA_cards_punch_card = arrays.punchCard
    this.DATA_cards_note = arrays.notes
    this.DATA_cards_archived = arrays.archived
  }

  private applySettings(settings: CardSettings): void {
    this.applyingSettings = true
    // 先设置配色，最后设置带 @Watch 的 UI_backdrop_choose。
    // 给 UI_backdrop_choose 赋值会同步触发 onChangeBackground -> DESIGN_use_image_backdrop，
    // 那时配色必须已经是新值，否则会用旧（甚至是空）配色算出 undefined 的字体色。
    this.DESIGN_color_scheme_light = settings.colorSchemeLight
    this.DESIGN_color_scheme_dark = settings.colorSchemeDark
    this.DESIGN_cards_blur_radius = settings.blurRadius
    this.DESIGN_min_card_size = settings.minCardSize
    this.DATA_app_open_time = settings.appOpenTime
    this.SETTINGS_color_scheme_edit_light = settings.colorSchemeLight.toString()
    this.SETTINGS_color_scheme_edit_dark = settings.colorSchemeDark.toString()
    this.DESIGN_use_backdrop = settings.useBackdrop

    this.UI_backdrop_choose = [settings.useBackdrop ? 1 : 0]
    this.applyingSettings = false
  }

  private applyWorkState(state: WorkState | undefined): void {
    if (state === undefined) {
      this.DATA_work_working_card_name = ''
      this.DATA_work_start = 0
      return
    }
    this.DATA_work_working_card_name = state.workingCardName
    this.DATA_work_start = state.workStart
    if (state.workLastEnd > 0) {
      this.DATA_work_last_end = state.workLastEnd
    }
  }

  private collectSettings(): CardSettings {
    const settings: CardSettings = {
      schemaVersion: SCHEMA_VERSION,
      useBackdrop: this.DESIGN_use_backdrop,
      colorSchemeLight: this.DESIGN_color_scheme_light,
      colorSchemeDark: this.DESIGN_color_scheme_dark,
      blurRadius: this.DESIGN_cards_blur_radius,
      minCardSize: this.DESIGN_min_card_size,
      appOpenTime: this.DATA_app_open_time,
      // 归档后一律从卡片流隐藏（该字段保留以兼容旧数据）
      hideArchived: true
    }
    return settings
  }

  private snapshotArrays(): CardArrays {
    const arrays: CardArrays = {
      name: this.DATA_cards_name,
      desc: this.DATA_cards_desc,
      length: this.DATA_cards_length,
      timeLimitDays: this.DATA_cards_time_limit,
      targetHours: this.DATA_cards_target,
      doneHours: this.DATA_cards_done,
      startAt: this.DATA_cards_start,
      endAt: this.DATA_cards_end,
      punchCard: this.DATA_cards_punch_card,
      notes: this.DATA_cards_note,
      archived: this.DATA_cards_archived
    }
    return arrays
  }

  /** 唯一的卡片落盘入口。写入由 Repository 串行排队。 */
  private persistCards(): void {
    if (!this.dataLoaded) {
      // 首次加载尚未成功完成时不写盘：否则会用空/半状态覆盖磁盘上的存档。
      // 这不是静默跳过——会明确记录错误以便排查。
      console.error("persistCards skipped: initial load has not completed successfully")
      return
    }
    // 长度对齐保护：toCards() 是按**下标**把 cardIds[i] 配给第 i 张卡片的。
    // 若 id 列表与 9 个数组因任何原因不等长，这里先补齐/截断，
    // 避免某一次保存把 id 错配给别的卡片（身份漂移）。
    while (this.cardIds.length < this.DATA_cards_name.length) {
      this.cardIds.push('')
    }
    if (this.cardIds.length > this.DATA_cards_name.length) {
      this.cardIds = this.cardIds.slice(0, this.DATA_cards_name.length)
    }
    const cards = toCards(this.snapshotArrays(), this.cardIds, systemDateTime.getTime())
    this.cardIds = []
    for (let i = 0; i < cards.length; i++) {
      this.cardIds.push(cards[i].id)
    }
    TaskRepository.saveCards(cards)
  }

  private persistSettings(): void {
    if (this.applyingSettings) {
      // 由 applySettings 内部赋值引发的 @Watch 回流，不是用户操作，无需落盘
      return
    }
    if (!this.dataLoaded) {
      console.error("persistSettings skipped: initial load has not completed successfully")
      return
    }
    TaskRepository.saveSettings(this.collectSettings())
  }

  /** 把当前计时状态收敛成一个 WorkState（导出与持久化共用，避免两处写法漂移）。 */
  private collectWorkState(): WorkState {
    const state: WorkState = {
      schemaVersion: SCHEMA_VERSION,
      workingCardName: this.DATA_work_working_card_name,
      workStart: this.DATA_work_start,
      workLastEnd: this.DATA_work_last_end
    }
    return state
  }

  private persistWorkState(): void {
    if (!this.dataLoaded) {
      console.error("persistWorkState skipped: initial load has not completed successfully")
      return
    }
    TaskRepository.saveWorkState(this.collectWorkState())
  }

  onBackPress(): boolean | void {
    if (this.STATUS_card_expanding != -1) {
      this.CARD_collapse_card_detail(false, true)
      return true
    }
  }

  build() {
    RelativeContainer() {
      Image($r("app.media.bg1"))
        .width(this.DETAILS_is_not_viewing_detail() ? "100%" : this.ENVIRONMENT_screen_width * 1.1)
        .height(this.DETAILS_is_not_viewing_detail() ? "100%" : this.ENVIRONMENT_screen_height * 1.1)
        .animation({ delay: 30, duration: 800, curve: Curve.ExtremeDeceleration })
        .alignRules({
          center: { anchor: "__container__", align: VerticalAlign.Center },
          middle: { anchor: "__container__", align: HorizontalAlign.Center }
        })

      // Backdrop

      Backdrop({
        UI_start_up_cover_continue_opacity: this.UI_start_up_cover_continue_opacity,
        DESIGN_use_backdrop: this.DESIGN_use_backdrop,
        DESIGN_color_scheme: this.DESIGN_color_scheme
      })

      // Backdrop Cover

      RelativeContainer() {

        HeroHeader({
          UI_Title_opacity: this.UI_Title_opacity,
          UI_Title_y_offset: this.UI_Title_y_offset,
          UI_subTitle_y_offset: this.UI_subTitle_y_offset,
          UI_subTitle_opacity: this.UI_subTitle_opacity,
          UI_Title_font_zoom: this.UI_Title_font_zoom,
          UI_Title_top_margin: this.UI_Title_top_margin,
          DESIGN_font_color: this.DESIGN_font_color
        })

        // BIG TITLE ("CUNJIN")

        WaterFlow({ scroller: this.scroller_main }) {

          FlowItem() {
          }.height(130)

          // TOP OF waterFlow

          FlowItem() {
            RelativeContainer() {
              Text(this.UI_is_first_open ? $r('app.string.Welcome') : $r(this.UI_top_card_greetings_address))
                .fontSize(25)
                .fontWeight(FontWeight.Bolder)
                .position({ x: 20, y: 20 })
                .fontColor(this.DESIGN_font_color) // TITLE GREETINGS

              Row() {
                JunHaoSymbolButton({
                  UI_image: $r('sys.symbol.plus'),
                  UI_text: $r("app.string.Settings_block_Add"),
                  DESIGN_font_color: this.DESIGN_font_color,
                  STATUS_trigger: this.STATUS_top_card_add_is_open,
                  STATUS_switch_to_arrow: this.STATUS_top_card_add_is_open,
                }).onClick(() => {
                  this.SETTINGS_reset_design_confirm = 0
                  this.STATUS_top_card_settings_is_open = false
                  this.ADD_name = ""
                  this.ADD_description = ""
                  if (this.STATUS_top_card_add_is_open) {
                    this.UI_top_card_height = 170
                    this.STATUS_top_card_add_is_open = false
                  } else {
                    this.UI_top_card_height = 845
                    this.STATUS_top_card_add_is_open = true // ADD LENGTH
                  }
                })

                JunHaoSymbolButton({
                  UI_image: $r('sys.symbol.gearshape'),
                  UI_text: $r("app.string.Settings_block_Settings"),
                  DESIGN_font_color: this.DESIGN_font_color,
                  STATUS_trigger: this.STATUS_top_card_settings_is_open,
                  STATUS_switch_to_arrow: this.STATUS_top_card_settings_is_open,
                }).onClick(() => {
                  this.SETTINGS_reset_design_confirm = 0
                  this.STATUS_top_card_add_is_open = false
                  if (this.STATUS_top_card_settings_is_open) {
                    this.UI_top_card_height = 170
                    this.STATUS_top_card_settings_is_open = false
                  } else {
                    this.UI_top_card_height = 1030
                    this.STATUS_top_card_settings_is_open = true // SETTINGS LENGTH
                  }
                })
              }.padding({ left: 10, right: 10 }).position({ y: 60 })

              // Block Head Buttons

              SettingsPanel({
                STATUS_top_card_settings_is_open: this.STATUS_top_card_settings_is_open,
                DESIGN_font_color: this.DESIGN_font_color,
                DESIGN_block_background_color: this.DESIGN_block_background_color,
                DESIGN_color_scheme_light: this.DESIGN_color_scheme_light,
                DESIGN_color_scheme_dark: this.DESIGN_color_scheme_dark,
                DESIGN_cards_blur_radius: this.DESIGN_cards_blur_radius,
                DESIGN_min_card_size: this.DESIGN_min_card_size,
                archived_ids: this.archivedIds(),
                archived_names: this.archivedNames(),
                SETTINGS_color_scheme_edit_light: this.SETTINGS_color_scheme_edit_light,
                SETTINGS_color_scheme_edit_dark: this.SETTINGS_color_scheme_edit_dark,
                SETTINGS_reset_design_confirm: this.SETTINGS_reset_design_confirm,
                UI_backdrop_choose: this.UI_backdrop_choose,
                UI_backdrop_segment_button_options: this.UI_backdrop_segment_button_options,
                onBlurCommit: () => {
                  this.persistSettings()
                },
                onMinSizeCommit: () => {
                  this.persistSettings()
                  this.UI_set_waterFlow_layout()
                },
                onUnarchive: (id: string) => {
                  this.MANAGE_unarchive_by_id(id)
                },
                onDeleteArchived: (id: string) => {
                  this.MANAGE_delete_by_id(id)
                },
                onApply: () => {
                  this.SETTINGS_apply_color_scheme()
                },
                onReset: () => {
                  this.SETTINGS_reset_design()
                },
                onExportData: () => {
                  this.DATA_export_json()
                },
                onImportData: () => {
                  this.DATA_import_json()
                }
              })

              // Settings Content

              AddCardPanel({
                STATUS_top_card_add_is_open: this.STATUS_top_card_add_is_open,
                DESIGN_font_color: this.DESIGN_font_color,
                DESIGN_block_background_color: this.DESIGN_block_background_color,
                ADD_name: this.ADD_name,
                ADD_description: this.ADD_description,
                ADD_length: this.ADD_length,
                ADD_length_description: this.ADD_length_description,
                ADD_time_limit: this.ADD_time_limit,
                ADD_time_limit_unit_or_description: this.ADD_time_limit_unit_or_description,
                ADD_value_target: this.ADD_value_target,
                ADD_value_target_unit_or_description: this.ADD_value_target_unit_or_description,
                onAdd: () => {
                  this.CARD_add_card()
                }
              })

              // Add Content

            }
          }
          .width("100%")
          // 设置面板是固定高度（1030），里面的「已归档」列表条数不定，
          // 所以按归档数量动态加高，避免列表被卡片下边缘裁掉。
          .height(this.UI_top_card_height +
            (this.STATUS_top_card_settings_is_open ? this.settingsArchivedExtraHeight() : 0))
          .borderRadius(16)
          .border({ width: 1, color: "#4D7A7A7A" })
          .backgroundEffect({
            radius: this.DESIGN_use_backdrop ? this.DESIGN_cards_blur_radius : 0,
            color: this.DESIGN_block_background_color
          })
          .backgroundColor(this.DESIGN_use_backdrop ? "#00000000" : this.DESIGN_color_scheme[5])
          .animation(this.DESIGN_animateParam(0))

          // SETTINGS AND ADD BLOCK

          FlowItem() {
            RelativeContainer() {
              Column({ space: 5 }) {
                Text(this.WORK_is_work_on_idle() ? $r("app.string.Work_Title_Work_Idle") :
                this.DATA_work_working_card_name)
                  .fontSize(25)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.DESIGN_font_color)
                  .width("100%")
                Text($r("app.string.Work_Title_Work_Ongoing"))
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.DESIGN_font_color)
                  .width("100%")
                Text(this.WORK_is_work_on_idle() ?
                ((this.ENVIRONMENT_current_timestamp - this.DATA_work_last_end) / 1000 / 3600).toFixed(2).toString() :
                  formatElapsedClock(this.ENVIRONMENT_current_timestamp - this.DATA_work_start))
                  .maxLines(1)
                  .fontSize(60)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.DESIGN_font_color)
                  .width("100%")
                Text($r('app.string.Add_Value_Unit_Hour'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Normal)
                  .fontColor(this.DESIGN_font_color)
                  .width("100%")
                  // 进行中显示的是 H:MM:SS 时钟，此时隐藏"小时"单位；
                  // 用 Hidden 而不是 None，保持这一行占位，布局不跳动。
                  .visibility(this.WORK_is_work_on_idle() ? Visibility.Visible : Visibility.Hidden)
              }.alignItems(HorizontalAlign.Start).height("100%")

              Button() {
                Column() {
                  SymbolGlyph(this.WORK_is_work_on_idle() ? $r("sys.symbol.battery_75percent") :
                  $r("sys.symbol.checkmark"))
                    .fontSize(45)
                    .fontColor([this.DESIGN_font_color])
                    .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), this.WORK_is_work_on_idle())
                  Text(this.WORK_is_work_on_idle() ? $r("app.string.Work_Title_Not_Working") :
                  $r('app.string.Work_Title_OK'))
                    .fontSize(16)
                    .fontColor(this.DESIGN_font_color)
                }.alignItems(HorizontalAlign.Center)
              }
              .type(ButtonType.Normal)
              .borderRadius(16)
              .alignRules({
                right: { anchor: "__container__", align: HorizontalAlign.End },
                bottom: { anchor: "__container__", align: VerticalAlign.Bottom }
              })
              .backgroundColor("#00000000")
              .padding(10)
              .onClick(() => {
                this.WORK_end_card()
              })
            }.width("100%").height("100%").align(Alignment.TopStart).padding(20)
          }
          .height(300)
          .width("100%")
          .borderRadius(16)
          .border({ width: 1, color: "#4D7A7A7A" })
          .backgroundEffect({
            radius: this.DESIGN_use_backdrop ? this.DESIGN_cards_blur_radius : 0,
            color: this.DESIGN_block_background_color
          })
          .backgroundColor(this.DESIGN_use_backdrop ? "#00000000" : this.DESIGN_color_scheme[5])
          .opacity(this.UI_status_card_opacity)
          .offset({ y: this.UI_status_card_offset })
          .animation(this.DESIGN_animateParam(0))

          // WORKING STATUS

          StatsPanel({
            // 归档卡片不计入全局统计：把 id 列表与"已归档 id"一起传下去，函数内部跳过
            today_hours: hoursOnDay(this.DATA_cards_punch_card, this.DATA_cards_start,
              this.ENVIRONMENT_current_timestamp, this.cardIds, this.archivedIds()),
            week_hours: hoursInRecentDays(this.DATA_cards_punch_card, this.DATA_cards_start,
              this.ENVIRONMENT_current_timestamp, 7, this.cardIds, this.archivedIds()),
            streak_days: currentStreak(this.DATA_cards_punch_card, this.DATA_cards_start,
              this.ENVIRONMENT_current_timestamp, this.cardIds, this.archivedIds()),
            total_hours: totalHours(this.DATA_cards_punch_card, this.cardIds,
              this.archivedIds()),
            active_days: activeDayCount(this.DATA_cards_punch_card, this.DATA_cards_start,
              this.cardIds, this.archivedIds()),
            font_color: this.DESIGN_font_color,
            block_background_color: this.DESIGN_block_background_color,
            use_backdrop: this.DESIGN_use_backdrop,
            blur_radius: this.DESIGN_cards_blur_radius,
            card_background: this.DESIGN_use_backdrop ? "#00000000" : this.DESIGN_color_scheme[5]
          })

          // STATS STRIP

          ForEach(this.DATA_cards_name, (_content: string, key: number) => {
            JunHaoBlock({
              ENVIRONMENT_waterFlow_column_count: this.UI_waterFlow_Columns,
              ENVIRONMENT_current_timestamp: this.ENVIRONMENT_current_timestamp,
              ENVIRONMENT_screen_width: this.ENVIRONMENT_screen_width,
              ENVIRONMENT_screen_height: this.ENVIRONMENT_screen_height,
              DESIGN_use_backdrop: this.DESIGN_use_backdrop,
              DESIGN_color_scheme: this.DESIGN_color_scheme,
              DESIGN_blur_radius: this.DESIGN_cards_blur_radius,
              DESIGN_font_color: this.DESIGN_font_color,
              STATUS_card_expanding: this.STATUS_card_expanding,
              STATUS_last_expanded: this.STATUS_card_index_of_last_expanded,
              DETAILS_remaining_days: this.UI_card_expanded_remaining_days,
              DETAILS_card_slogan: this.UI_card_expanded_slogan_of_time,
              index: key,
              UI_timeout: 100 * key,
              archived: this.cardArchivedAt(key),
              hide_by_archive: this.cardArchivedAt(key),
              name: this.DATA_cards_name[key],
              desc: this.DATA_cards_desc[key],
              card_length: this.DATA_cards_length[key],
              target: this.DATA_cards_target[key],
              done: this.DATA_cards_done[key],
              time_limit: this.DATA_cards_time_limit[key],
              start: this.DATA_cards_start[key],
              end: this.DATA_cards_end[key],
              DETAILS_Edit_name_edit: this.EDIT_name,
              DETAILS_Edit_description_edit: this.EDIT_description,
              DETAILS_Edit_Length: this.EDIT_length,
              DETAILS_Edit_Length_Description: this.EDIT_length_description
            })

          })

          // MAIN CARDS

          FlowItem() {
            RelativeContainer() {
              Text($r("app.string.Encouragement"))
                .textAlign(TextAlign.End)
                .fontColor(this.DESIGN_font_color)
                .fontSize(30)
                .fontWeight(FontWeight.Bolder)
                .alignRules({
                  right: { anchor: "__container__", align: HorizontalAlign.End },
                  bottom: { anchor: "__container__", align: VerticalAlign.Bottom }
                })
                .offset({ y: -40 })
            }.height("100%")
          }.animation(this.DESIGN_animateParam(0)).height(this.ENVIRONMENT_screen_height)

          // ENCOURAGEMENT

        }
        .width("100%")
        .margin({ top: 90, bottom: 20 })
        .opacity(this.UI_top_card_opacity)
        .position({ y: this.UI_top_card_offset + 20 })
        .columnsGap(10)
        .borderRadius(16)
        .edgeEffect(EdgeEffect.Spring)
        .onAreaChange(() => {
          this.UI_top_card_offset = 0
          this.UI_top_card_opacity = 100
          setTimeout(() => {
            this.UI_status_card_offset = 0
            this.UI_status_card_opacity = 100
          }, 600)
        })
        .onScrollIndex((first) => {
          if (first == 0) {
            this.UI_Title_top_margin = 90
            this.UI_Title_font_zoom = 1
          } else if (first > 0) {
            this.UI_Title_top_margin = 10
            this.UI_Title_font_zoom = 0.7
          }
        })
        .animation(this.DESIGN_animateParam(400))

        .columnsTemplate(this.UI_waterFlow_Layout)
        .rowsGap(10)
        .animation(this.DESIGN_animateParam(0))

        .onClick(() => {
          if (this.STATUS_card_expanding != -1) {
            this.STATUS_card_expanding = -1
          }
        })
        .padding({ left: 10, right: 10 })

        // MAIN BODY OF CARDS

        // ── 卡片详情弹层的「外壳」，按设计永久保留在 Index 内 ────────────────────
        // Scroll / 其下的 Column / 内层 WaterFlow 这三个节点不能抽成组件：
        //   1. Scroll 持有 this.scroller_card_expand（页面私有 Scroller，删除卡片后要用它
        //      scrollTo 复位），并用 .alignRules 锚定到根容器的 __container__，
        //      负责弹层居中与整屏遮挡；z 序由声明顺序决定，必须留在原位置。
        //   2. Column 上的 .onTouch 负责"下滑自动收起详情"，依赖
        //      event.target.area.globalPosition.y > 100 这个绝对坐标判断。
        //   3. 内层 WaterFlow 的 .columnsTemplate 决定宽屏 1fr 1fr / 窄屏 1fr，
        //      其 FlowItem 的先后就是视觉顺序，多包一层容易把顺序或列数改掉。
        // 因此弹层内容按"一个个 FlowItem / 独立组件"逐个搬出，外壳本身留在页面里。
        Scroll(this.scroller_card_expand) {
          Column() {
            CardDetailSpacer({
              detail_hidden: this.DETAILS_is_not_viewing_detail(),
              screen_height: this.ENVIRONMENT_screen_height,
              onReset: () => {
                this.DETAILS_reset_when_expanding()
              }
            })

            // PLACEHOLDER

            WaterFlow() {
              CardInfoBlock({
                card_name: this.DATA_cards_name[this.STATUS_card_index_of_last_expanded],
                card_desc: this.DATA_cards_desc[this.STATUS_card_index_of_last_expanded],
                card_target: this.DATA_cards_target[this.STATUS_card_expanding],
                done_text: this.DATA_cards_done[this.STATUS_card_index_of_last_expanded] != undefined ?
                  this.DATA_cards_done[this.STATUS_card_index_of_last_expanded].toFixed(2) : "",
                font_color: this.DESIGN_font_color,
                detail_hidden: this.DETAILS_is_not_viewing_detail()
              })

              // BASIC INFO

              DoneGraph({
                done_value: this.CARD_get_done_value(),
                done_percentage: this.CARD_get_done_percentage(),
                target: this.DATA_cards_target[this.STATUS_card_index_of_last_expanded],
                font_color: this.DESIGN_font_color,
                detail_hidden: this.DETAILS_is_not_viewing_detail(),
                wide_screen: this.DETAILS_is_wide_screen()
              })

              // DONE GRAPH

              TimeGraph({
                slogan_key: this.UI_card_expanded_slogan_of_time,
                time_limit: this.DATA_cards_time_limit[this.STATUS_card_index_of_last_expanded],
                remaining_days: this.UI_card_expanded_remaining_days,
                time_left_percentage: this.CARD_get_time_left_percentage(),
                font_color: this.DESIGN_font_color,
                detail_hidden: this.DETAILS_is_not_viewing_detail(),
                wide_screen: this.DETAILS_is_wide_screen()
              })

              // TIME LEFT GRAPH

              EstimatingBlock({
                average_left_text: this.CARD_get_average_daily_work_left_processed_for_display(),
                card_name: this.DATA_cards_name[this.STATUS_card_expanding],
                work_is_idle: this.WORK_is_work_on_idle(),
                font_color: this.DESIGN_font_color,
                block_background_color: this.DESIGN_block_background_color,
                detail_hidden: this.DETAILS_is_not_viewing_detail(),
                wide_screen: this.DETAILS_is_wide_screen(),
                forecast_status: this.CARD_forecast_status(),
                forecast_days: this.CARD_forecast_days(),
                forecast_late: this.CARD_forecast_late(),
                STATUS_card_index_of_last_expanded: this.STATUS_card_index_of_last_expanded,
                onStartWork: (card_name: string) => {
                  this.WORK_start_card(card_name)
                },
                onCollapseDetail: () => {
                  this.CARD_collapse_card_detail(true, true)
                }
              })

              // EXPLANATION

              FlowItem() {
                JunHaoDataBoard({
                  DATA_list_of_data: this.DATA_cards_punch_card[this.STATUS_card_index_of_last_expanded],
                  DATA_reference_value: this.CARD_get_average_daily_work(),
                  DATA_first_day_stamp: this.DATA_cards_start[this.STATUS_card_index_of_last_expanded],
                  DATA_today_index:
                  this.UTIL_get_relative_days_passed(
                    this.DATA_cards_start[this.STATUS_card_index_of_last_expanded], this.ENVIRONMENT_current_timestamp
                  ),
                  STATUS_current_expand: this.STATUS_card_expanding,
                  ENVIRONMENT_screen_width: this.ENVIRONMENT_screen_width,
                  DESIGN_block_color: this.DESIGN_font_color,
                  DESIGN_button_text_color: this.DESIGN_block_background_color,
                  UI_chosen_block_index: this.UI_card_expanded_viewing_detail_of_block_index
                })
                  .offset({ y: (this.DETAILS_is_not_viewing_detail()) ? 100 : 0 })
                  .visibility((this.DETAILS_is_not_viewing_detail()) ? Visibility.Hidden : Visibility.Visible)
                  .animation(this.DESIGN_animateParam(this.DETAILS_is_not_viewing_detail() ? 0 : 550))
              }.width("100%").height(270)

              SubmittedBlock({
                submitted_text: this.STATUS_card_index_of_last_expanded == -1 ? "0" :
                  this.DATA_cards_punch_card[this.STATUS_card_index_of_last_expanded][this.UI_card_expanded_viewing_detail_of_block_index].toFixed(4),
                date_text: this.CARD_get_date_of_chosen()[0],
                font_color: this.DESIGN_font_color,
                detail_hidden: this.DETAILS_is_not_viewing_detail(),
                wide_screen: this.DETAILS_is_wide_screen()
              })

              // DATA BOARD

              DayNotePanel({
                note_text: this.noteFor(this.STATUS_card_index_of_last_expanded,
                  this.UI_card_expanded_viewing_detail_of_block_index),
                date_text: this.CARD_get_date_of_chosen()[0],
                detail_hidden: this.DETAILS_is_not_viewing_detail(),
                font_color: this.DESIGN_font_color,
                block_background_color: this.DESIGN_block_background_color,
                use_backdrop: this.DESIGN_use_backdrop,
                blur_radius: this.DESIGN_cards_blur_radius,
                card_background: this.DESIGN_use_backdrop ? "#00000000" : this.DESIGN_color_scheme[5],
                onEdit: (text: string) => {
                  this.CARD_edit_day_note(text)
                }
              })

              EditCard({
                card_name: this.DATA_cards_name[this.STATUS_card_index_of_last_expanded],
                card_desc: this.DATA_cards_desc[this.STATUS_card_index_of_last_expanded],
                card_length: this.DATA_cards_length[this.STATUS_card_index_of_last_expanded],
                STATUS_card_expanding: this.STATUS_card_expanding,
                font_color: this.DESIGN_font_color,
                block_background_color: this.DESIGN_block_background_color,
                detail_hidden: this.DETAILS_is_not_viewing_detail(),
                EDIT_name: this.EDIT_name,
                EDIT_description: this.EDIT_description,
                EDIT_length: this.EDIT_length,
                EDIT_length_description: this.EDIT_length_description,
                onSave: () => {
                  this.EDIT_commit_card()
                }
              })

              // SETTINGS I

              ManagePanel({
                card_name: this.DATA_cards_name[this.STATUS_card_expanding],
                working_card_name: this.DATA_work_working_card_name,
                delete_confirm: this.EDIT_delete_card_confirm,
                font_color: this.DESIGN_font_color,
                block_background_color: this.DESIGN_block_background_color,
                detail_hidden: this.DETAILS_is_not_viewing_detail(),
                archive_confirm: this.EDIT_archive_confirm,
                onMoveToTop: () => {
                  this.MANAGE_move_to_top()
                },
                onArchive: () => {
                  this.MANAGE_archive_card()
                },
                onDeleteCard: () => {
                  this.MANAGE_delete_card()
                }
              })

              // MANAGING

            }
            .columnsGap(16)
            .rowsGap(20)
            .borderRadius(16)
            .backgroundEffect({
              radius: this.DESIGN_use_backdrop ? this.DESIGN_cards_blur_radius : 0,
              color: this.DESIGN_use_backdrop ? this.DESIGN_color_scheme[4] : this.DESIGN_color_scheme[5]
            })
            .backgroundColor(this.DESIGN_use_backdrop ? "#00000000" : this.DESIGN_color_scheme[5])
            .padding(this.DETAILS_is_wide_screen() ? 32 : 20)
            .height((this.DETAILS_is_wide_screen() ? 2 : 4) * 800)
            .width(Math.min(this.ENVIRONMENT_screen_width - 40, 600))
            .columnsTemplate(this.DETAILS_is_wide_screen() ? "1fr 1fr" : "1fr")
            .border({ width: 1, color: "#4d7a7a7a" })

            // INFO BODY
          }.width("100%").alignItems(HorizontalAlign.Center).onTouch((event) => {
            if (event.type == TouchType.Up) {
              if (event.target.area.globalPosition.y != undefined) {
                if (event.target.area.globalPosition.y > 100) {
                  this.CARD_collapse_card_detail(false, false) // Auto Collapse Detail Card when Swiping down
                }
              }
            }
          }).margin({ bottom: 40 })
        }
        .backgroundColor("#70000000")
        .opacity((this.DETAILS_is_not_viewing_detail()) ? 0 : 1)
        .animation(this.DESIGN_animateParam(0))
        .visibility((this.DETAILS_is_not_viewing_detail()) ? Visibility.None : Visibility.Visible)
        .animation((this.DETAILS_is_not_viewing_detail()) ? this.DESIGN_animateParam(300) : { duration: 0 })
        .alignRules({
          center: { anchor: "__container__", align: VerticalAlign.Center },
          middle: { anchor: "__container__", align: HorizontalAlign.Center }
        })
        .width("100%")
        .height("100%")
        .edgeEffect(EdgeEffect.Spring)

        // CARD POP UP

      }.onAreaChange((_o, n) => { /* DETERMINE SCREEN SIZE AND LAYOUT */
        this.ENVIRONMENT_screen_width = Number(n.width) + 20
        this.ENVIRONMENT_screen_height = Number(n.height) + 30

        if (this.DETAILS_is_not_viewing_detail()) {
          this.UI_set_waterFlow_layout()
        }

        let hour = Number(Date().split(" ")[4].split(":")[0])
        if (hour < 5) {
          this.STATUS_current_time_period = "Sleep"
        } else if (hour < 11) {
          this.STATUS_current_time_period = "Morning"
        } else if (hour < 14) {
          this.STATUS_current_time_period = "Noon"
        } else if (hour < 18) {
          this.STATUS_current_time_period = "Afternoon"
        } else if (hour < 23) {
          this.STATUS_current_time_period = "Evening"
        } else {
          this.STATUS_current_time_period = "Sleep"
        }
        this.UI_top_card_greetings_address =
          "app.string.Greetings_" + this.STATUS_current_time_period /* Determine current time period for Greetings */
      })

      // 新建失败提示（自绘弹窗：跟随主题配色，且不依赖系统弹窗的默认文字颜色）
      // 放在 SHELL 之后、StartupCover 之前：盖住内容层，但不盖住启动封面。
      // 标题与正文由 STATUS_add_failed_title / _message 两个资源 key 决定。

      Row() {
        Column({ space: 18 }) {
          Text($r(this.STATUS_add_failed_title))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.DESIGN_block_background_color)
            .textAlign(TextAlign.Center)

          Text($r(this.STATUS_add_failed_message))
            .fontSize(15)
            .fontColor(this.DESIGN_block_background_color)
            .textAlign(TextAlign.Center)
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Button() {
            Text($r("app.string.General_OK"))
              .fontSize(15)
              .fontColor(this.DESIGN_font_color)
              .fontWeight(FontWeight.Bolder)
          }
          .width("100%")
          .padding(5)
          .backgroundColor(this.DESIGN_block_background_color)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .onClick(() => {
            this.STATUS_add_failed_warning_is_open = false
          })
        }
        .width("80%")
        .padding(20)
        .borderRadius(16)
        .backgroundColor(this.DESIGN_font_color)
        .shadow({ radius: 20, color: '#40000000', offsetX: 0, offsetY: 8 })
      }
      .width("100%")
      .height("100%")
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#66000000')
      .visibility(this.STATUS_add_failed_warning_is_open ? Visibility.Visible : Visibility.None)
      .onClick(() => {
        // 点遮罩也能关掉
        this.STATUS_add_failed_warning_is_open = false
      })

      // Body

      StartupCover({
        UI_start_up_cover_continue_opacity: this.UI_start_up_cover_continue_opacity,
        DESIGN_color_scheme: this.DESIGN_color_scheme
      })

      // COVER CONTINUES

    }.backgroundColor($r('app.color.start_window_background'))

  }

  onChangeBackground() {
    if (this.UI_backdrop_choose[0] == 0) {
      // If chosen not to use image backdrop
      this.DESIGN_use_image_backdrop(false)
    } else {
      // If chosen to use image backdrop
      this.DESIGN_use_image_backdrop(true)
    }
    this.UI_set_SegmentButton_Options()
  }

  onColorModeChange() { // Load Colors
    // 只是切换明暗配色，不需要重新读存储（旧版会重读一遍，属于多余的 I/O）
    this.DESIGN_update_key_colors()
  }

  onDirectionChange() {
  }

  onCardExpand() {
    if (this.DETAILS_is_not_viewing_detail()) {
      this.UI_set_waterFlow_layout() // if collapsed
    } else { // if is going to expand
    }
  }

  // 说明：原 DESIGN_read_design() 已删除。
  // 设置现在统一由 TaskRepository.loadSettings() 一次性读出，再经 applySettings() 投影到状态，
  // 不再需要 6 个独立的异步读取（也就不会出现"读到一半、颜色数组只有一项"的中间态）。

  DESIGN_update_key_colors() {
    if (this.ENVIRONMENT_current_color_mode == ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      this.DESIGN_color_scheme = this.DESIGN_color_scheme_light
    } else {
      this.DESIGN_color_scheme = this.DESIGN_color_scheme_dark
    }
    this.DESIGN_font_color = this.DESIGN_use_backdrop ? this.DESIGN_color_scheme[2] : this.DESIGN_color_scheme[3]
    this.DESIGN_block_background_color =
      this.DESIGN_use_backdrop ? this.DESIGN_color_scheme[4] : this.DESIGN_color_scheme[5]
    this.UI_set_SegmentButton_Options()
  }

  DESIGN_use_image_backdrop(use_or_not: boolean) {
    this.DESIGN_use_backdrop = use_or_not
    this.DESIGN_font_color = this.DESIGN_use_backdrop ? this.DESIGN_color_scheme[2] : this.DESIGN_color_scheme[3]
    this.DESIGN_block_background_color =
      this.DESIGN_use_backdrop ? this.DESIGN_color_scheme[4] : this.DESIGN_color_scheme[5]
    this.persistSettings()
  }

  DESIGN_store_current_design() {
    console.log("DESIGN_store_current_design" + this.DESIGN_color_scheme_light.toString() + ' light_qwq')
    console.log("DESIGN_store_current_design" + this.DESIGN_color_scheme_dark.toString() + ' dark_qwq')
    this.persistSettings()
  }

  /**
   * 设置面板「确认」按钮的动作。
   * 语句顺序与拆分前面板内的 onClick 完全一致：
   * 先重排 WaterFlow，再套用两份配色串，最后重算颜色并落盘。
   */
  SETTINGS_apply_color_scheme() {
    this.UI_set_waterFlow_layout()

    if (this.SETTINGS_color_scheme_edit_light != "") {
      this.DESIGN_color_scheme_light = this.SETTINGS_color_scheme_edit_light.split(",")
    }
    if (this.SETTINGS_color_scheme_edit_dark != "") {
      this.DESIGN_color_scheme_dark = this.SETTINGS_color_scheme_edit_dark.split(",")
    }
    this.DESIGN_update_key_colors()
    this.DESIGN_store_current_design()
  }

  /**
   * 设置面板「恢复默认」的第二次点击动作。
   * 语句顺序与拆分前一致，四项重置值（450 / 25）与默认配色来源保持不变。
   */
  SETTINGS_reset_design() {
    this.DESIGN_color_scheme_light = this.DESIGN_color_scheme_light_default.split(",")
    this.DESIGN_color_scheme_dark = this.DESIGN_color_scheme_dark_default.split(",")
    this.DESIGN_min_card_size = 450
    this.DESIGN_cards_blur_radius = 25
    this.DESIGN_update_key_colors()
    this.DESIGN_store_current_design()
    this.UI_set_waterFlow_layout()
  }

  DESIGN_animateParam(delay: number) {
    // 实现已抽到 design/JunHaoUi.ets，参数与原来完全一致（300ms + ExtremeDeceleration）。
    // 保留此方法是为了不修改 build() 中大量既有的 this.DESIGN_animateParam(...) 调用点。
    return animateParam(delay)
  }

  DETAILS_is_wide_screen() {
    return this.ENVIRONMENT_screen_width - 40 > 600
  }

  DETAILS_is_not_viewing_detail() {
    return (this.STATUS_card_expanding == -1)
  }

  UI_set_SegmentButton_Options() {
    this.UI_backdrop_segment_button_options = SegmentButtonOptions.tab({
      buttons: [{ text: $r("app.string.Settings_Content_Background_Color") },
        { text: $r("app.string.Settings_Content_Background_Image") }],
      fontColor: this.DESIGN_font_color,
      selectedFontColor: this.DESIGN_block_background_color,
      fontWeight: FontWeight.Medium,
      selectedFontWeight: FontWeight.Bolder,
      selectedBackgroundColor: this.DESIGN_font_color
    })
  }

  UI_set_waterFlow_layout() {
    this.UI_waterFlow_Columns = 0
    this.UI_waterFlow_Layout = ""
    for (let i = this.ENVIRONMENT_screen_width; i > 0; i = i - this.DESIGN_min_card_size) {
      this.UI_waterFlow_Layout = this.UI_waterFlow_Layout + "1fr "
      this.UI_waterFlow_Columns += 1
    }

    if (this.UI_waterFlow_Columns == 0) {
      this.UI_waterFlow_Columns = 1 // Total length of head and first head block
    } /* Initialize WaterFlow layout according to screen width
         * */
  }

  CARD_add_card() {
    if (this.ADD_name == "") { // Save Card and Add
      // Empty Name Cannot Add
      // 不再静默返回：否则"名字没写进页面状态"这类问题只会表现为"点确定没反应"。
      console.error("CARD_add_card: empty name, card not added " +
        "(check that ADD_name is @Link, not @Prop, in AddCardPanel)")
      this.STATUS_add_failed_title = "app.string.Add_Card_Empty_Title"
      this.STATUS_add_failed_message = "app.string.Add_Card_Empty_Message"
      this.STATUS_add_failed_warning_is_open = true
      return false
    }

    if (this.DATA_cards_name.includes(this.ADD_name)) {
      // Name crash
      console.error("CARD_add_card: duplicate name '" + this.ADD_name + "', card not added")
      // 明确告诉用户为什么没创建（原来是静默 return，表现为"点确定没反应"）
      this.STATUS_add_failed_title = "app.string.Add_Card_Duplicate_Title"
      this.STATUS_add_failed_message = "app.string.Add_Card_Duplicate_Message"
      this.STATUS_add_failed_warning_is_open = true
      return false
    }

    this.DATA_cards_name.push(this.ADD_name)
    if (this.ADD_description == "") {
      console.log("Add Card: empty desc, replacing with default '喵 meow'")
      this.DATA_cards_desc.push("喵 meow")
    } else {
      this.DATA_cards_desc.push(this.ADD_description)
    }
    this.DATA_cards_length.push(this.ADD_length)
    this.DATA_cards_time_limit.push(this.ADD_time_limit)
    this.DATA_cards_target.push(this.ADD_value_target)
    this.DATA_cards_done.push(0)
    this.DATA_cards_start.push(this.ENVIRONMENT_current_timestamp)
    this.DATA_cards_end.push(this.ENVIRONMENT_current_timestamp + 86400000 * this.ADD_time_limit)
    this.DATA_cards_punch_card.push(this.WORK_create_punch_card(this.ADD_time_limit))
    // 备注与打卡数组等长：新卡片补一条空备注数组
    this.DATA_cards_note.push(this.WORK_create_punch_card(this.ADD_time_limit).map((_v: number) => ''))
    // 新卡片一律未归档（这一步也保证不会继承任何旧标记）
    this.DATA_cards_archived.push(false)
    // 同步扩展 id 列表（占位空串，由 toCards() 生成真正的 id），
    // 否则 toCards() 会用错位的旧 id 配给新卡片。
    this.cardIds = appendPlaceholderId(this.cardIds)
    this.CARD_storeCards()

    this.ADD_name = ""
    this.ADD_description = ""

    this.UI_top_card_height = 170
    this.STATUS_top_card_add_is_open = false
    // Collapse Add Card Panel

    // 新建的卡片排到最前面：这样"跳转到创建的卡片"和"跳转到最上面"是同一件事。
    // VIEW_move_card_to_index 内部会同步全部数组 + cardIds 并落盘，
    // 因此"新增 + 置顶"最终只多一次串行写；只有一张卡时它自己会早退，不会重复写。
    if (this.DATA_cards_name.length > 1) {
      this.VIEW_move_card_to_index(this.DATA_cards_name.length - 1, 0)
    }

    // 停位：新建完成后停在「计时卡」上，统计条与卡片在下一屏。
    // 用 ScrollAlign.START 让计时卡上边缘与视口上边缘齐平，
    // 而不是只保证"进入可视区"（那样上边缘会被前面的节点压住）。
    this.scroller_main.scrollToIndex(this.MAIN_FLOW_TIMER_CARD_INDEX(), true, ScrollAlign.START)

    return true

  }

  /**
   * 交换两张卡片的位置。
   *
   * 修复点：
   * 1. 9 个数组与 cardIds 必须同步移动。persistCards() 调用的 toCards() 是按**下标**
   *    把 existingIds[i] 配给第 i 张卡片的，id 不跟着走会造成身份漂移。
   * 2. 换位后必须落盘，否则重启会回到旧顺序。
   *
   * 说明：当前工程没有调用点（唯一的换位入口是"置顶"按钮与开始计时，
   * 两者都走 VIEW_move_card_to_index）。保留并修正此方法，是为了消除
   * "改了顺序却不落盘"的陷阱，将来接上拖拽手势可直接使用。
   */
  VIEW_switch_card_position(first: number, second: number) {
    this.applyArrays(swapCardPositions(this.snapshotArrays(), first, second))
    this.cardIds = swapIdPositions(this.cardIds, first, second)
    this.persistCards()
  }

  /**
   * 把第 from 张卡片移动到 to 位置（"置顶"按钮与开始计时都调用它）。
   *
   * 修复点：9 个数组 + cardIds 同步位移，并在动作结束时落盘。
   * 写入由 TaskRepository 的串行队列保证顺序，一次换位只产生一次写入。
   */
  VIEW_move_card_to_index(from: number, to: number) {
    if (from == to) {
      return // 位置未变化，不产生多余写盘
    }
    this.applyArrays(moveCardToIndex(this.snapshotArrays(), from, to))
    this.cardIds = moveIdToIndex(this.cardIds, from, to)
    this.persistCards()
  }

  CARD_collapse_card_detail(scroll_home: boolean, scroll_detail: boolean) {
    this.STATUS_card_expanding = -1
    if (scroll_detail) {
      this.scroller_card_expand.scrollTo({ xOffset: 0, yOffset: 0 })
    }
    if (scroll_home) {
      this.scroller_main.scrollToIndex(this.STATUS_card_index_of_last_expanded + this.MAIN_FLOW_FIRST_CARD_INDEX(), true)
    }
  }

  // ── 卡片查询：只负责「取状态 -> 交给 model/CardQueries 的纯函数」───────────────
  // 计算逻辑已抽到 model/CardQueries.ets（纯函数，可单测）。
  // 这里保留同名方法，调用点、参数含义与调用时机均未改变。

  CARD_get_done_value() {
    return doneValue(this.DATA_cards_target[this.STATUS_card_index_of_last_expanded],
      this.DATA_cards_done[this.STATUS_card_index_of_last_expanded])
  }

  CARD_get_done_percentage() {
    return donePercentage(this.DATA_cards_target[this.STATUS_card_index_of_last_expanded],
      this.DATA_cards_done[this.STATUS_card_index_of_last_expanded])
  }

  CARD_get_time_left_percentage() {
    return timeLeftPercentage(this.DATA_cards_time_limit[this.STATUS_card_index_of_last_expanded],
      this.DATA_cards_end[this.STATUS_card_index_of_last_expanded],
      this.ENVIRONMENT_current_timestamp)
  }

  CARD_get_average_daily_work_left_processed_for_display() {
    return averageDailyWorkLeftForDisplay(this.DATA_cards_target[this.STATUS_card_index_of_last_expanded],
      this.DATA_cards_done[this.STATUS_card_index_of_last_expanded],
      this.DATA_cards_time_limit[this.STATUS_card_index_of_last_expanded],
      this.UI_card_expanded_remaining_days)
  }

  CARD_get_average_daily_work() {
    return averageDailyWork(this.DATA_cards_target[this.STATUS_card_index_of_last_expanded],
      this.DATA_cards_time_limit[this.STATUS_card_index_of_last_expanded])
  }

  CARD_get_today_block_index() {
    return todayBlockIndex(this.DATA_cards_punch_card[this.STATUS_card_index_of_last_expanded],
      this.DATA_cards_start[this.STATUS_card_index_of_last_expanded],
      this.ENVIRONMENT_current_timestamp)
  }

  CARD_get_date_of_chosen() {
    return dateOfChosen(this.DATA_cards_start[this.STATUS_card_index_of_last_expanded],
      this.UI_card_expanded_viewing_detail_of_block_index)
  }

  /**
   * 卡片详情每次"展开/收起"时执行的复位（原占位 Row 的 onAreaChange 内联函数体，逐行搬出）。
   *
   * 两件事都必须做：
   *   1. 把删除按钮的二次确认状态复位，避免上次点过一次"删除"后重新展开直接处于待确认态；
   *   2. 把数据看板选中的日期跳回"今天"，避免停留在上次翻到的日子。
   * 由 CardDetailSpacer 的高度变化（detail_hidden 切换）触发，触发时机与拆分前一致。
   */
  DETAILS_reset_when_expanding() {
    this.EDIT_delete_card_confirm = false
    this.EDIT_archive_confirm = false
    this.UI_card_expanded_viewing_detail_of_block_index = this.CARD_get_today_block_index()
  }

  /**
   * 管理面板「置顶」按钮的动作（原内联函数体，逐行搬出）。
   *
   * 顺序不能变：先把卡片移到 0、再复位两个下标、最后让主滚动区跳到卡片流。
   * 落盘已由 VIEW_move_card_to_index() 内部完成，这里不再重复保存。
   */
  MANAGE_move_to_top() {
    this.VIEW_move_card_to_index(this.STATUS_card_expanding, 0) // SWITCH CARD POSITIONS
    this.STATUS_card_expanding = 0
    this.STATUS_card_index_of_last_expanded = 0
    this.scroller_main.scrollToIndex(this.MAIN_FLOW_FIRST_CARD_INDEX(), true)
    // 落盘已在 VIEW_move_card_to_index() 内完成，此处不再重复保存
  }

  /**
   * 管理面板「删除」按钮的动作（原内联函数体，逐行搬出）。
   *
   * 顺序不能变：
   *   1. 正在计时的卡片不允许删除（提前 return）；
   *   2. 第一次点击只翻"再确认一次"，第二次才真正删除；
   *   3. 9 个平行数组逐个 splice，再同步移除 cardIds（removeIdAt）——顺序不能调换，
   *      否则 removeIdAt 拿到的下标与数组长度不再对应；
   *   4. 弹层滚回顶部、两个下标复位，最后 CARD_storeCards() 统一落盘。
   *
   * 删除必须留在页面里：cardIds 是 @State 之外的私有字段，两个 Scroller 也是私有成员，
   * 都无法作为组件属性传出。
   */
  MANAGE_delete_card() {
    if (this.DATA_cards_name[this.STATUS_card_expanding] ==
    this.DATA_work_working_card_name) { // ONGOING NO DELETE
      return
    }

    // DELETE CARD
    if (this.EDIT_delete_card_confirm == false) {
      this.EDIT_delete_card_confirm = true
    } else if (this.EDIT_delete_card_confirm == true) {
      this.EDIT_delete_card_confirm = false

      this.DATA_cards_name.splice(this.STATUS_card_expanding, 1)
      this.DATA_cards_desc.splice(this.STATUS_card_expanding, 1)
      this.DATA_cards_length.splice(this.STATUS_card_expanding, 1)
      this.DATA_cards_time_limit.splice(this.STATUS_card_expanding, 1)
      this.DATA_cards_target.splice(this.STATUS_card_expanding, 1)
      this.DATA_cards_done.splice(this.STATUS_card_expanding, 1)
      this.DATA_cards_start.splice(this.STATUS_card_expanding, 1)
      this.DATA_cards_end.splice(this.STATUS_card_expanding, 1)
      this.DATA_cards_punch_card.splice(this.STATUS_card_expanding, 1)
      this.DATA_cards_note.splice(this.STATUS_card_expanding, 1)
      this.DATA_cards_archived.splice(this.STATUS_card_expanding, 1)
      // 同步移除对应 id，保持 id 列表与 9 个数组等长
      this.cardIds = removeIdAt(this.cardIds, this.STATUS_card_expanding)


      this.scroller_card_expand.scrollTo({ xOffset: 0, yOffset: 0 })
      this.STATUS_card_index_of_last_expanded = this.STATUS_card_expanding - 1
      this.STATUS_card_expanding = -1

      this.CARD_storeCards()
    }
  }

  /**
   * 主卡片流（WaterFlow）里固定节点的下标。
   * 顺序：0 顶部留白胶囊 / 1 顶部卡（问候+设置+添加） / 2 计时卡 / 3 统计条 / 4… 卡片 / 末尾 鼓励语。
   * 集中在这里，避免各处硬编码（之前 collapse 用 +3、置顶用 2，都因统计条插入而偏了一格）。
   */
  MAIN_FLOW_FIRST_CARD_INDEX(): number {
    return 4
  }

  /** 计时卡的下标（新建完成后停在这里，统计条与卡片在下一屏）。 */
  MAIN_FLOW_TIMER_CARD_INDEX(): number {
    return 2
  }

  /** 该下标对应的卡片是否已归档（与卡片数组同下标，不按 id 反查）。 */
  cardArchivedAt(index: number): boolean {
    if (index < 0 || index >= this.DATA_cards_archived.length) {
      return false
    }
    return this.DATA_cards_archived[index] === true
  }

  /**
   * 归档当前展开的卡片（与删除同款"两次点击"确认）。
   *
   * 第一次点击：只把确认位翻成 true，按钮文案变成「再点一次以确认」，不做任何数据改动；
   * 第二次点击：真正归档（标记 + 落盘），然后回到主界面。
   *
   * 归档后卡片会立刻从卡片流隐藏，所以这里必须主动收起详情，
   * 否则会停在一张已经不在列表里的卡片上。
   */
  MANAGE_archive_card() {
    const index = this.STATUS_card_expanding
    if (index < 0 || index >= this.DATA_cards_archived.length) {
      return
    }
    if (this.EDIT_archive_confirm == false) {
      // 第一次点击：只翻确认位
      this.EDIT_archive_confirm = true
      return
    }

    // 第二次点击：真正归档
    this.EDIT_archive_confirm = false
    const next: boolean[] = []
    for (let i = 0; i < this.DATA_cards_archived.length; i++) {
      next.push(i == index ? true : this.DATA_cards_archived[i] === true)
    }
    // 整体重新赋值：@State 只观察数组整体赋值，不观察单个元素写入
    this.DATA_cards_archived = next
    this.CARD_storeCards()
    this.UTIL_toast('已归档')

    // 回到主界面：收起详情弹层（不强制改主滚动位置，保留用户原来的浏览位置）
    this.CARD_collapse_card_detail(false, true)
  }

  /**
   * 进度预测：按最近 7 天的实际投入推算还要多久。
   * 计算在 model/CardStats.forecastCard（纯函数，已单测）；
   * 这里只负责取当前展开那张卡的字段。
   */
  private CARD_forecast(): CardForecast {
    const index = this.STATUS_card_expanding
    if (index < 0 || index >= this.DATA_cards_name.length) {
      // 没有展开任何卡片时给一个"不显示"的结果，避免读到 undefined 算出 NaN
      return forecastCard([], 0, 0, 1001, 1, 0, 0, 7)
    }
    return forecastCard(this.DATA_cards_punch_card[index], this.DATA_cards_start[index],
      this.DATA_cards_done[index], this.DATA_cards_target[index], this.DATA_cards_time_limit[index],
      this.DATA_cards_end[index], this.ENVIRONMENT_current_timestamp, 7)
  }

  CARD_forecast_status(): string {
    return this.CARD_forecast().status
  }

  CARD_forecast_days(): number {
    return this.CARD_forecast().daysNeeded
  }

  CARD_forecast_late(): number {
    return this.CARD_forecast().daysLate
  }

  /** 已归档卡片的名称列表（供设置面板展示）。 */
  archivedNames(): string[] {
    const names: string[] = []
    for (let i = 0; i < this.DATA_cards_archived.length; i++) {
      if (this.DATA_cards_archived[i] === true && i < this.DATA_cards_name.length) {
        names.push(this.DATA_cards_name[i])
      }
    }
    return names
  }

  /** 已归档卡片的 id 列表（统计排除用）。 */
  archivedIds(): string[] {
    const ids: string[] = []
    for (let i = 0; i < this.DATA_cards_archived.length; i++) {
      if (this.DATA_cards_archived[i] === true && i < this.cardIds.length) {
        ids.push(this.cardIds[i])
      }
    }
    return ids
  }

  /** 读取「第 cardIndex 张卡、第 dayIndex 天」的备注；越界返回空串。 */
  noteFor(cardIndex: number, dayIndex: number): string {
    if (cardIndex < 0 || cardIndex >= this.DATA_cards_note.length) {
      return ''
    }
    const row = this.DATA_cards_note[cardIndex]
    if (row == undefined || dayIndex < 0 || dayIndex >= row.length) {
      return ''
    }
    const value = row[dayIndex]
    return value == undefined ? '' : value
  }

  /**
   * 写入当前查看那天的备注。
   * 数组元素写入留在页面里（与 EDIT_commit_card 同一模式）；每次输入即落盘，
   * 因为备注很短、且 TaskRepository 内部是串行写队列，中途退出也不会丢字。
   */
  CARD_edit_day_note(text: string) {
    const cardIndex = this.STATUS_card_index_of_last_expanded
    const dayIndex = this.UI_card_expanded_viewing_detail_of_block_index
    if (cardIndex < 0 || cardIndex >= this.DATA_cards_note.length) {
      return
    }
    const row = this.DATA_cards_note[cardIndex]
    if (row == undefined || dayIndex < 0 || dayIndex >= row.length) {
      return
    }
    row[dayIndex] = text
    // 整体重新赋值，确保 @State 观察得到（V1 不观察嵌套数组元素写入）
    this.DATA_cards_note[cardIndex] = row
    this.CARD_storeCards()
  }

  /**
   * 设置面板里「已归档」列表需要额外的高度。
   * 设置面板本身是固定高度（1030），列表条数不定，这里把多出来的行高补上，
   * 否则列表会被顶部卡片的下边缘裁掉（用户反馈：只看到"已归档 3 张"标题）。
   */
  settingsArchivedExtraHeight(): number {
    let count = 0
    for (let i = 0; i < this.DATA_cards_archived.length; i++) {
      if (this.DATA_cards_archived[i] === true) {
        count++
      }
    }
    if (count == 0) {
      return 0
    }
    // 标题行约 44；每行现在是"名字 + 按钮"两行，约 52（含内边距），再留一点余量
    return 44 + count * 56
  }

  /**
   * 按 id 取消归档（设置面板的「已归档」列表用）。
   * id 只用于定位这一次操作的下标，不参与任何"是否归档"的判定。
   */
  MANAGE_unarchive_by_id(id: string) {
    const index = this.cardIds.indexOf(id)
    if (index < 0 || index >= this.DATA_cards_archived.length) {
      return
    }
    const next: boolean[] = []
    for (let i = 0; i < this.DATA_cards_archived.length; i++) {
      next.push(i == index ? false : this.DATA_cards_archived[i] === true)
    }
    this.DATA_cards_archived = next
    this.CARD_storeCards()
    this.UTIL_toast('已取消归档')
  }

  /**
   * 按 id 删除一张卡片（设置面板「已归档」列表里的删除按钮用）。
   *
   * 与卡片详情里的 `MANAGE_delete_card()` 保持同一套规则：
   *   1. 正在计时的卡片不允许删除；
   *   2. 9 个平行数组 + 每日备注 + 归档标记 + cardIds 全部同步删除；
   *   3. 修正两个"当前展开"下标（被删的就是它 -> 收起；在它前面 -> 前移一位）；
   *   4. CARD_storeCards() 统一落盘。
   *
   * 与 `MANAGE_delete_card()` 的区别只是入口：那边从"当前展开的卡片"出发，
   * 这边从列表里的一个 id 出发，所以删除下标由 id 反查、且不需要二次确认状态
   * （二次确认由列表按钮自己负责）。
   */
  MANAGE_delete_by_id(id: string) {
    const index = this.cardIds.indexOf(id)
    if (index < 0 || index >= this.DATA_cards_name.length) {
      return
    }
    // 正在计时的卡片不可删除：结束计时前删掉它会让整段工作时长无处记账
    if (this.DATA_cards_name[index] == this.DATA_work_working_card_name) {
      this.UTIL_toast('正在计时的卡片不能删除，请先结束计时')
      return
    }

    this.DATA_cards_name.splice(index, 1)
    this.DATA_cards_desc.splice(index, 1)
    this.DATA_cards_length.splice(index, 1)
    this.DATA_cards_time_limit.splice(index, 1)
    this.DATA_cards_target.splice(index, 1)
    this.DATA_cards_done.splice(index, 1)
    this.DATA_cards_start.splice(index, 1)
    this.DATA_cards_end.splice(index, 1)
    this.DATA_cards_punch_card.splice(index, 1)
    this.DATA_cards_note.splice(index, 1)
    this.DATA_cards_archived.splice(index, 1)
    this.cardIds = removeIdAt(this.cardIds, index)

    // 两个下标用同一个纯函数修正，避免"删前面的卡片后仍指向旧位置"
    const wasExpanded = this.STATUS_card_expanding == index
    this.STATUS_card_expanding = shiftIndexAfterDelete(this.STATUS_card_expanding, index)
    this.STATUS_card_index_of_last_expanded =
      shiftIndexAfterDelete(this.STATUS_card_index_of_last_expanded, index)
    if (wasExpanded) {
      // 删掉的正是当前展开的那张：把弹层滚回顶部，避免停在已不存在的位置
      this.scroller_card_expand.scrollTo({ xOffset: 0, yOffset: 0 })
    }

    this.CARD_storeCards()
    this.UTIL_toast('已删除')
  }

  /**
   * 编辑卡片的提交动作（原 EditCard 面板确认按钮的内联函数体，逐行搬出）。
   *
   * 顺序必须保持不变：
   *   1. 若被改的正是"正在计时的那张卡"，先把计时状态里的卡片名同步过去并落盘，
   *      否则"结束"时 indexOf 返回 -1，整段工作时长会被判定为卡片不存在而丢失；
   *   2. 写回名称；
   *   3. 写回描述（空则回填默认 "喵 meow"）；
   *   4. 写回卡片长度；
   *   5. CARD_storeCards() 统一落盘（仍经 TaskRepository）。
   *
   * 三处数组元素赋值刻意留在页面里：卡片数组是父页面的 @State 事实源，
   * 不跨组件边界传递，从根本上避免 @Link 数组元素写入的观察/落盘时序问题。
   */
  EDIT_commit_card() {
    // 改名时同步计时状态里的卡片名。
    // 否则"结束"时 indexOf 返回 -1，整段工作时长会被判定为卡片不存在而丢失。
    if (this.DATA_cards_name[this.STATUS_card_index_of_last_expanded] ==
      this.DATA_work_working_card_name && this.EDIT_name != "") {
      this.DATA_work_working_card_name = this.EDIT_name
      this.persistWorkState()
    }
    this.DATA_cards_name[this.STATUS_card_index_of_last_expanded] = this.EDIT_name
    if (this.EDIT_description == "") {
      console.log("Edit Card: empty desc, replacing with default '喵 meow'")
      this.DATA_cards_desc[this.STATUS_card_index_of_last_expanded] = "喵 meow"
    } else {
      this.DATA_cards_desc[this.STATUS_card_index_of_last_expanded] = this.EDIT_description
    }
    this.DATA_cards_length[this.STATUS_card_index_of_last_expanded] = this.EDIT_length

    this.CARD_storeCards()
  }

  CARD_storeCards() {
    // 统一走 Repository：一次写入整个 JSON 文档，
    // 不再有旧版 9 次独立 put 造成的"只写了一半"的中间状态。
    this.persistCards()
  }

  WORK_start_card(name: string) {
    if (this.WORK_is_work_on_idle()) {
      this.DATA_work_working_card_name = name
      this.DATA_work_start = this.ENVIRONMENT_current_timestamp
      this.WORK_storeWorkingState()
      this.VIEW_move_card_to_index(this.STATUS_card_expanding, 0)
      // 卡片顺序的落盘已在 VIEW_move_card_to_index() 内完成
    } else {
      console.log("WORK_start_card: Cannot Start Card Since There Already Exists an Ongoing Card")
    }
  }

  WORK_end_card() {
    if (this.WORK_is_work_on_idle()) {
      console.log("WORK_end_card: Cannot End Card Since NO Card is Ongoing") // Is currently not working
      return
    }

    // 修复：用当前真实时间计算，而不是缓存的 tick 值。
    // 旧写法在定时器被系统冻结/清理时会把整段时长记成 0 小时。
    const now = systemDateTime.getTime()
    this.ENVIRONMENT_current_timestamp = now
    const time_length = (now - this.DATA_work_start) / 1000 / 3600

    // 修复：先校验索引再累加。
    // 旧版直接写 DATA_cards_done[indexOf(...)]，当卡片被改名/删除时 index == -1，
    // 于是执行 done[-1] += hours —— 写进一个非索引属性，整段工作时长静默丢失。
    const index = this.DATA_cards_name.indexOf(this.DATA_work_working_card_name)
    if (index == -1) {
      console.log("WORK_end_card: target card no longer exists, hours cannot be credited")
    } else if (Number.isFinite(time_length) && time_length > 0) {
      this.DATA_cards_done = creditDone(this.DATA_cards_done, index, time_length)
      this.WORK_punch_punch_card(this.DATA_work_working_card_name, time_length)
    }

    this.DATA_work_working_card_name = ""
    this.DATA_work_start = 0
    this.DATA_work_last_end = now
    this.WORK_storeWorkingState()
    this.CARD_storeCards() // End Card Work
  }

  WORK_is_work_on_idle() {
    return this.DATA_work_working_card_name == ""
  }

  WORK_storeWorkingState() {
    this.persistWorkState()
  }

  WORK_create_punch_card(length: number) {
    // 与旧实现等价：length + 1 个 0（最后一位用于逾期追加）
    return createPunchCard(length)
  }

  WORK_punch_punch_card(name: string, record: number) {
    // 修复：先校验索引，再读取任何卡片数据。
    // 旧版先读 DATA_cards_start[index] / 计算 today_index，之后才判断 index == -1，
    // 中间会产生 undefined 与 NaN（虽然旧版随后 return 丢弃了它们，但顺序本身就是隐患）。
    const index = this.DATA_cards_name.indexOf(name)
    if (index == -1) {
      console.log("Punch: failed due to an nonexistent work")
      return false
    }
    if (!Number.isFinite(record) || record <= 0) {
      console.log("Punch: skipped due to invalid record")
      return false
    }

    const rows = this.DATA_cards_punch_card
    const row: number[] | undefined = index < rows.length ? rows[index] : undefined
    if (row === undefined || row.length == 0) {
      console.log("Punch: failed due to missing punch card row")
      return false
    }

    const time_start = this.DATA_cards_start[index]
    const today_index = this.UTIL_get_relative_days_passed(time_start, this.ENVIRONMENT_current_timestamp)
    const limit = this.DATA_cards_time_limit[index]

    if (Number.isFinite(limit) && today_index >= limit) {
      // Overdue Punch：追加到最后一位（保持与原实现一致的语义）
      console.log("Punch: overdue, added to last position")
      // 不可变更新：整体赋回 @State，ArkUI V1 才能观测到变化
      this.DATA_cards_punch_card = applyPunch(rows, index, row.length - 1, record)
      return false
    }

    this.DATA_cards_punch_card =
      applyPunch(rows, index, clampDayIndex(today_index, row.length), record)

    console.log("Punch: success")
    return true
  }

  UTIL_get_relative_days_passed(from: number, to: number) {
    return relativeDaysPassed(from, to)
  }

  UTIL_get_connected_date(timestamp: number) {
    // 实现已抽到 model/CardQueries.ets 的 connectedDate()（纯函数，可单测）。
    // 保留此方法名，避免改动既有调用点。
    return connectedDate(timestamp)
  }

  UTIL_refresh_current_time_stamp() {
      this.ENVIRONMENT_current_timestamp = systemDateTime.getTime()
  }

  /** 轻量提示。用 UIContext 的 PromptAction（@since 11），不走已废弃的全局 promptAction。 */
  UTIL_toast(message: string) {
    const options: promptAction.ShowToastOptions = { message: message, duration: 2000 }
    // showToast 声明了 @throws（401/100001），这里显式兜住：
    // 提示失败不应该影响导出/导入本身的结果。
    try {
      this.getUIContext().getPromptAction().showToast(options)
    } catch (error) {
      console.error('UTIL_toast failed: ' + JSON.stringify(error))
    }
  }

  /**
   * 导出：把当前卡片 / 设置 / 计时状态打包成备份文件，交给系统"另存为"选择器。
   *
   * 流程：取上下文 -> 生成备份文本 -> 弹保存选择器 -> 写入 URI。
   * 文件内容由 model/ExportDocument 生成（内部就是 cards_v2 / settings_v2 / work_state_v2
   * 三个既有 payload 的原文，不引入新协议），磁盘读写由 repository/BackupFile 完成。
   * 本方法**不**写 KV，纯导出。
   */
  async DATA_export_json() {
    const context = this.getUIContext().getHostContext()
    if (context == undefined) {
      this.UTIL_toast('导出失败：无法获取应用上下文')
      return
    }
    if (!this.dataLoaded) {
      this.UTIL_toast('导出失败：数据尚未加载完成')
      return
    }

    const now = systemDateTime.getTime()
    const cards = toCards(this.snapshotArrays(), this.cardIds, now)
    const text = buildExportText(cards, this.collectSettings(), this.collectWorkState(), now)

    const uri = await pickSaveTarget(context, exportFileName(now))
    if (uri == undefined) {
      return // 用户取消，不打扰
    }
    if (writeTextToUri(uri, text)) {
      this.UTIL_toast('已导出 ' + cards.length.toString() + ' 张卡片')
    } else {
      this.UTIL_toast('导出失败：写入文件出错')
    }
  }

  /**
   * 导入：选文件 -> 解析校验 -> 经 TaskRepository 落盘 -> 刷新页面状态。
   *
   * 安全顺序：**先校验、再落盘、最后改 UI**。
   *   · 解析失败（非 JSON / 格式不符 / 版本过高 / 不含卡片）直接返回，不动任何数据；
   *   · 落盘统一走 TaskRepository.saveCards / saveSettings / saveWorkState，
   *     仍是唯一写入路径，不新建第二份事实源；
   *   · 落盘成功后才把内存状态同步成导入的数据，避免出现"界面显示新数据、磁盘还是旧数据"。
   *
   * 关于旧数据迁移：导入后 cards_v2 一定非空，TaskRepository.ensureLegacyMigrated()
   * 内部的"新数据已存在"分支会直接打标记返回，因此旧 KV 永远不会覆盖导入的数据。
   */
  async DATA_import_json() {
    const context = this.getUIContext().getHostContext()
    if (context == undefined) {
      this.UTIL_toast('导入失败：无法获取应用上下文')
      return
    }
    if (!this.dataLoaded) {
      this.UTIL_toast('导入失败：数据尚未加载完成')
      return
    }

    const uri = await pickImportSource(context)
    if (uri == undefined) {
      return // 用户取消
    }
    const text = readTextFromUri(uri)
    if (text == undefined) {
      this.UTIL_toast('导入失败：无法读取文件')
      return
    }

    const parsed: ExportParseResult = parseExportText(text)
    if (!parsed.ok) {
      this.UTIL_toast('导入失败：' + this.UTIL_import_reason(parsed.reason))
      return
    }

    const settings = parsed.settingsText != "" ?
      deserializeSettings(parsed.settingsText, this.settingsDefaults()) : undefined

    // ── 导入前自动快照（安全网）──────────────────────────────
    // 导入是覆盖式操作，先把"当前数据"静默写一份到应用沙箱（filesDir），
    // 误导入时可以拿它再导回来。写快照失败则**中止导入**（fail-closed），
    // 宁可这次不导入，也不要在没有回溯手段的情况下覆盖用户数据。
    const nowMs = systemDateTime.getTime()
    const preText = buildExportText(
      toCards(this.snapshotArrays(), this.cardIds, nowMs),
      this.collectSettings(),
      this.collectWorkState(),
      nowMs)
    const snapshotPath = writeTextToSandbox(context, preImportFileName(nowMs), preText)
    if (snapshotPath == undefined) {
      this.UTIL_toast('导入已取消：无法写入本地快照，未改动任何数据')
      return
    }
    console.info('DATA_import_json pre-import snapshot: ' + snapshotPath)

    try {
      await TaskRepository.saveCards(parsed.cards)
      if (settings != undefined) {
        await TaskRepository.saveSettings(settings)
      }
      if (parsed.work != undefined) {
        await TaskRepository.saveWorkState(parsed.work)
      }
    } catch (error) {
      console.error('DATA_import_json save failed: ' + JSON.stringify(error))
      this.UTIL_toast('导入失败：写入数据出错。已保留导入前快照：' + snapshotPath)
      return
    }

    // 落盘成功后再同步内存状态（applyCards 会同时重建 cardIds）
    this.applyCards(parsed.cards)
    if (settings != undefined) {
      this.applySettings(settings)
    }
    if (parsed.work != undefined) {
      this.applyWorkState(parsed.work)
    }
    this.UI_set_waterFlow_layout()
    this.UI_set_SegmentButton_Options()
    this.UTIL_toast('已导入 ' + parsed.cardCount.toString() + ' 张卡片')
  }

  /** 把解析器的失败代码翻译成可读提示。 */
  UTIL_import_reason(reason: string): string {
    if (reason == 'empty') {
      return '文件为空'
    }
    if (reason == 'not-json') {
      return '不是有效的备份文件'
    }
    if (reason == 'wrong-format') {
      return '不是本应用的备份文件'
    }
    if (reason == 'unsupported-version') {
      return '备份版本过高，请升级应用'
    }
    if (reason == 'missing-cards') {
      return '备份缺少卡片数据'
    }
    if (reason == 'no-cards') {
      return '备份中没有卡片'
    }
    return reason
  }
}
