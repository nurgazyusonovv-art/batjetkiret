"""
BATJETKIRET Payment Bot
Handles balance top-up requests via Telegram
"""
import asyncio
import logging
import os
import sys
from pathlib import Path
from aiogram import Bot, Dispatcher, F, types
from aiogram.filters import Command, CommandStart
from aiogram.types import Message, ReplyKeyboardMarkup, KeyboardButton
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.fsm.storage.memory import MemoryStorage

# Support running this file directly: `python app/bot/payment_bot.py`
PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

from app.models.topup import TopUpRequest
from app.core.database import get_db_url

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Get bot token from environment
BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "8696534686:AAGusULCLSuVK1QsWuZcCP4blaorfTM3N_g")

# Initialize bot and dispatcher
bot = Bot(token=BOT_TOKEN)
storage = MemoryStorage()
dp = Dispatcher(storage=storage)

# Database setup
engine = create_engine(get_db_url())
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class TopUpState(StatesGroup):
    """States for top-up process"""
    waiting_for_unique_id = State()
    waiting_for_amount = State()
    waiting_for_screenshot = State()


def get_flow_keyboard():
    """Keyboard shown during top-up flow."""
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="🔄 Кайра баштоо")],
            [KeyboardButton(text="📞 Контакт")],
        ],
        resize_keyboard=True,
    )


def get_main_keyboard():
    """Get main menu keyboard"""
    keyboard = ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="💰 Баланс толуктоо")],
            [KeyboardButton(text="🔄 Кайра баштоо")],
            [KeyboardButton(text="❓ Жардам"), KeyboardButton(text="📞 Контакт")],
        ],
        resize_keyboard=True,
    )
    return keyboard


@dp.message(CommandStart())
async def cmd_start(message: Message):
    """Handle /start command"""
    await message.answer(
        "🚗 <b>BATJETKIRET төлөм ботуна кош келиңиз!</b>\n\n"
        "Бул бот аркылуу балансыңызды коопсуз жана тез толуктай аласыз.\n\n"
        "<b>Баштоо:</b> <b>💰 Баланс толуктоо</b> баскычын басыңыз.\n"
        "Кандай учурда болбосун <b>🔄 Кайра баштоо</b> менен кайра баштасаңыз болот.",
        reply_markup=get_main_keyboard(),
        parse_mode="HTML"
    )


@dp.message(Command("restart"))
@dp.message(F.text == "🔄 Кайра баштоо")
async def restart_flow(message: Message, state: FSMContext):
    """Reset current state and return user to main menu."""
    await state.clear()
    await message.answer(
        "🔄 <b>Процесс кайра башталды</b>\n\n"
        "Эми кайрадан <b>💰 Баланс толуктоо</b> баскычы аркылуу уланта аласыз.",
        reply_markup=get_main_keyboard(),
        parse_mode="HTML",
    )


@dp.message(F.text == "💰 Баланс толуктоо")
async def start_topup(message: Message, state: FSMContext):
    """Start balance top-up процесс"""
    await state.set_state(TopUpState.waiting_for_unique_id)
    await message.answer(
        "📋 <b>Балансты толуктоо</b>\n\n"
        "1) Жеке номериңизди жөнөтүңүз (мисалы: <code>BJ000123</code>)\n"
        "2) Андан кийин сумманы киргизесиз\n"
        "3) Акырында төлөм скриншотун жөнөтөсүз\n\n"
        "Жеке номер профилиңизде көрсөтүлгөн.",
        parse_mode="HTML",
        reply_markup=get_flow_keyboard(),
    )


@dp.message(TopUpState.waiting_for_unique_id)
async def process_unique_id(message: Message, state: FSMContext):
    """Process user unique ID"""
    unique_id = message.text.strip().upper()
    
    # Validate format (BJ followed by 6 digits)
    if not unique_id.startswith("BJ") or not unique_id[2:].isdigit() or len(unique_id) != 8:
        await message.answer(
            "❌ Туура эмес формат!\n"
            "Номер <b>BJ</b> жана 6 сандан турушу керек (мисалы: <code>BJ000123</code>)",
            parse_mode="HTML",
        )
        return
    
    # Save to state
    await state.update_data(unique_id=unique_id)
    await state.set_state(TopUpState.waiting_for_amount)
    
    await message.answer(
        f"✅ Жеке номериңиз: <b>{unique_id}</b>\n\n"
        "Эми толуктай турган сумманы жазыңыз.\n"
        "Минималдуу сумма: <b>10 сом</b>",
        parse_mode="HTML",
        reply_markup=get_flow_keyboard(),
    )


@dp.message(TopUpState.waiting_for_amount)
async def process_amount(message: Message, state: FSMContext):
    """Process top-up amount"""
    try:
        amount = float(message.text)
        if amount < 10:
            await message.answer("❌ Минимум сумма 10 сом")
            return
    except ValueError:
        await message.answer("❌ Туура эмес сумма! Сандарды гана жөнөтүңүз.")
        return
    
    # Save to state
    await state.update_data(amount=amount)
    await state.set_state(TopUpState.waiting_for_screenshot)
    
    data = await state.get_data()
    unique_id = data["unique_id"]
    
    await message.answer(
        f"💳 <b>Төлөм маалыматы</b>\n\n"
        f"Жеке номериңиз: <code>{unique_id}</code>\n"
        f"Сумма: <b>{amount} сом</b>\n\n"
        f"📱 <b>Төлөм жүргүзүү номери:</b>\n"
        f"<b>+996990310893</b>\n\n"
        f"Төлөм жүргүзүү тартиби:\n"
        f"1️⃣ <b>Мбанк</b> же <b>ОБанк</b> тиркемесине кириңиз\n"
        f"2️⃣ Номерге төлөм жүргүзүңүз: <code>+996990310893</code>\n"
        f"3️⃣ Сумма: <b>{amount} сом</b>\n"
        f"4️⃣ ⚠️ <b>КОММЕНТАРИЙГЕ ЖЕКЕ НОМЕРИҢИЗДИ КӨРСӨТҮҢҮЗ: {unique_id}</b>\n"
        f"5️⃣ Төлөмдүн скриншотун бул ботко жөнөтүңүз\n\n"
        f"❗ Эскертүү: Комментарийде жеке номериңизди көрсөтпөсөңүз, баланс толукталбайт!",
        parse_mode="HTML",
        reply_markup=get_flow_keyboard(),
    )


@dp.message(TopUpState.waiting_for_screenshot, F.photo)
async def process_screenshot(message: Message, state: FSMContext):
    """Process payment screenshot"""
    data = await state.get_data()
    unique_id = data["unique_id"]
    amount = data["amount"]
    
    # Get photo file
    photo = message.photo[-1]  # Get highest resolution
    file_id = photo.file_id
    
    # Save to database
    db = SessionLocal()
    try:
        topup_request = TopUpRequest(
            unique_id=unique_id,
            amount=amount,
            telegram_user_id=message.from_user.id,
            telegram_username=message.from_user.username or "unknown",
            screenshot_file_id=file_id,
            status="PENDING"
        )
        db.add(topup_request)
        db.commit()
        
        await message.answer(
            f"✅ <b>Өтүнүчүңүз кабыл алынды!</b>\n\n"
            f"Жеке номер: <code>{unique_id}</code>\n"
            f"Сумма: <b>{amount} сом</b>\n\n"
            f"Администратор тастыктагандан кийин балансыңыз толукталат.\n"
            f"Бул 5-30 мүнөт ичинде болот.",
            reply_markup=get_main_keyboard(),
            parse_mode="HTML"
        )
    except Exception as e:
        logger.error(f"Error saving topup request: {e}")
        await message.answer(
            "❌ Ката чыкты! Кайра аракет кылыңыз же админге кайрылыңыз.",
            reply_markup=get_main_keyboard()
        )
    finally:
        db.close()
    
    await state.clear()


@dp.message(TopUpState.waiting_for_screenshot)
async def invalid_screenshot(message: Message):
    """Handle invalid screenshot"""
    await message.answer(
        "❌ Сүрөт жөнөтүңүз! Төлөмдүн скриншоту керек.\n"
        "Эгер башынан баштайм десеңиз: <b>🔄 Кайра баштоо</b>",
        parse_mode="HTML"
    )


@dp.message(F.text == "❓ Жардам")
async def cmd_help(message: Message):
    """Show help message"""
    await message.answer(
        "📖 <b>Колдонуу боюнча жардам</b>\n\n"
        "1️⃣ Баланс толуктоо үчүн <b>💰 Баланс толуктоо</b> баскычын басыңыз\n"
        "2️⃣ Жеке номериңизди жөнөтүңүз (профилде көрсөтүлгөн)\n"
        "3️⃣ Канча сомго толуктайсыз\n"
        "4️⃣ Төлөм жүргүзүп, скриншот жөнөтүңүз\n"
        "5️⃣ Тастыктоодан кийин баланс толукталат\n\n"
        "Кез келген учурда <b>🔄 Кайра баштоо</b> аркылуу процессти нөлдөн баштасаңыз болот.\n\n"
        "Суроолор болсо төмөнкү контакттарга жазыңыз.",
        parse_mode="HTML"
    )


@dp.message(F.text == "📞 Контакт")
async def cmd_contact(message: Message):
    """Show contact info"""
    await message.answer(
        "📞 <b>Контакт маалымат</b>\n\n"
        "Суроолор, сунуштар жана техникалык колдоо үчүн:\n"
        "📱 WhatsApp: <b>+996990310893</b>\n"
        "📞 Чалуу: <b>+996990310893</b>\n"
        "📧 Email: support@batjetkiret.kg\n"
        "💬 Telegram: @batjetkiret_support",
        parse_mode="HTML"
    )


@dp.message()
async def fallback_handler(message: Message):
    """Handle unknown messages outside flow states."""
    await message.answer(
        "Менюдан керектүү бөлүктү тандаңыз:\\n"
        "• 💰 Баланс толуктоо\\n"
        "• ❓ Жардам\\n"
        "• 📞 Контакт\\n"
        "• 🔄 Кайра баштоо",
        reply_markup=get_main_keyboard(),
    )


async def main():
    """Start the bot"""
    logger.info("Starting BATJETKIRET Payment Bot...")
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
