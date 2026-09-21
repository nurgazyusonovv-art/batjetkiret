#!/usr/bin/env python3
"""
App Store Asset Generator for Batken Express (BatJetkiret)
Generates:
1. App Store Icon (1024x1024, RGB PNG, no alpha)
2. 6.7" / 6.9" Screenshots (1290 x 2796) - iPhone 16 Pro Max / 15 Pro Max
3. 6.5" Screenshots (1242 x 2688) - iPhone 11 Pro Max / XS Max
4. Promotional Feature Graphic (1024 x 500)
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(BASE_DIR, 'app_store_assets')

os.makedirs(os.path.join(ASSETS_DIR, 'icon'), exist_ok=True)
os.makedirs(os.path.join(ASSETS_DIR, 'screenshots_6.7_inch'), exist_ok=True)
os.makedirs(os.path.join(ASSETS_DIR, 'screenshots_6.5_inch'), exist_ok=True)
os.makedirs(os.path.join(ASSETS_DIR, 'marketing'), exist_ok=True)

FONT_BOLD_PATH = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
FONT_REGULAR_PATH = '/System/Library/Fonts/Supplemental/Arial.ttf'

def get_font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()

def create_gradient(width, height, top_color, bottom_color):
    base = Image.new('RGB', (width, height), top_color)
    top_r, top_g, top_b = top_color
    bot_r, bot_g, bot_b = bottom_color
    
    draw = ImageDraw.Draw(base)
    for y in range(height):
        factor = y / height
        r = int(top_r + (bot_r - top_r) * factor)
        g = int(top_g + (bot_g - top_g) * factor)
        b = int(top_b + (bot_b - top_b) * factor)
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    return base

def draw_rounded_rect(draw, bbox, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(bbox, radius=radius, fill=fill, outline=outline, width=width)

def draw_lightning(draw, cx, cy, size, fill):
    """Draws a crisp lightning bolt vector shape."""
    s = size / 2.0
    points = [
        (cx + s * 0.1, cy - s),
        (cx - s * 0.5, cy - s * 0.1),
        (cx - s * 0.05, cy - s * 0.1),
        (cx - s * 0.3, cy + s),
        (cx + s * 0.5, cy + s * 0.05),
        (cx + s * 0.05, cy + s * 0.05),
    ]
    draw.polygon(points, fill=fill)

def draw_star(draw, cx, cy, radius, fill):
    """Draws a 5-point star."""
    points = []
    for i in range(10):
        angle = i * math.pi / 5 - math.pi / 2
        r = radius if i % 2 == 0 else radius * 0.45
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(points, fill=fill)

def generate_icon():
    source_icon = os.path.join(BASE_DIR, 'frontend/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png')
    out_icon_path = os.path.join(ASSETS_DIR, 'icon', 'AppStore_Icon_1024x1024.png')
    
    if os.path.exists(source_icon):
        im = Image.open(source_icon).convert('RGB')
        im = im.resize((1024, 1024), Image.Resampling.LANCZOS)
        im.save(out_icon_path, 'PNG', optimize=True)
        print(f"Generated App Store Icon: {out_icon_path}")
    else:
        im = Image.new('RGB', (1024, 1024), (235, 30, 30))
        draw = ImageDraw.Draw(im)
        draw.ellipse([80, 80, 944, 944], outline=(255, 220, 40), width=24)
        draw.text((512, 560), "БАТКЕН", fill=(255, 255, 255), font=get_font(FONT_BOLD_PATH, 100), anchor="mm")
        draw.text((512, 680), "ЭКСПРЕСС", fill=(255, 255, 255), font=get_font(FONT_REGULAR_PATH, 48), anchor="mm")
        im.save(out_icon_path, 'PNG', optimize=True)

def build_screenshot_card(screen_idx, inner_w, inner_h):
    ui = Image.new('RGBA', (inner_w, inner_h), (255, 255, 255, 255))
    draw = ImageDraw.Draw(ui)
    
    # Status bar
    font_status = get_font(FONT_BOLD_PATH, 34)
    draw.text((70, 40), "09:41", fill=(30, 30, 30), font=font_status)
    # Dynamic Island
    draw_rounded_rect(draw, [inner_w//2 - 120, 25, inner_w//2 + 120, 75], 25, fill=(10, 10, 10))
    
    header_font = get_font(FONT_BOLD_PATH, 38)
    sub_font = get_font(FONT_REGULAR_PATH, 28)

    if screen_idx == 0:
        # Header
        draw_lightning(draw, 80, 150, 40, (255, 107, 0))
        draw.text((115, 150), "BATKEN EXPRESS", fill=(255, 107, 0), font=header_font, anchor="lm")
        draw.text((inner_w - 90, 150), "Откоруу", fill=(130, 130, 130), font=sub_font, anchor="rm")
        
        # Central illustration box
        draw_rounded_rect(draw, [80, 230, inner_w - 80, 850], 48, fill=(240, 244, 255))
        draw.ellipse([inner_w//2 - 140, 400, inner_w//2 + 140, 680], fill=(108, 99, 255, 220))
        draw.ellipse([inner_w//2 - 85, 455, inner_w//2 + 85, 625], fill=(255, 255, 255))
        draw_lightning(draw, inner_w//2, 540, 80, (108, 99, 255))
        
        # Title
        draw.text((inner_w//2, 930), "Заказды бат кабыл ал", fill=(20, 24, 40), font=get_font(FONT_BOLD_PATH, 52), anchor="mm")
        draw.text((inner_w//2, 1020), "Жакынкы заказдарды бир тийуу\nменен ыкчам кабыл алыныз", fill=(100, 110, 130), font=get_font(FONT_REGULAR_PATH, 32), anchor="mm", align="center")
        
        # Indicator dots
        draw_rounded_rect(draw, [inner_w//2 - 60, 1130, inner_w//2 - 10, 1146], 8, fill=(108, 99, 255))
        draw.ellipse([inner_w//2 + 10, 1130, inner_w//2 + 26, 1146], fill=(210, 215, 230))
        draw.ellipse([inner_w//2 + 40, 1130, inner_w//2 + 56, 1146], fill=(210, 215, 230))
        
        # Action button
        draw_rounded_rect(draw, [80, 1220, inner_w - 80, 1340], 36, fill=(108, 99, 255))
        draw.text((inner_w//2, 1280), "Кийинки  ->", fill=(255, 255, 255), font=get_font(FONT_BOLD_PATH, 36), anchor="mm")

    elif screen_idx == 1:
        # Header Location
        draw.text((60, 130), "Баткен шаары, Борбор", fill=(30, 30, 30), font=get_font(FONT_BOLD_PATH, 36))
        draw.text((60, 180), "Кайда жеткиребиз?", fill=(130, 130, 130), font=sub_font)
        
        # Search bar
        draw_rounded_rect(draw, [60, 240, inner_w - 60, 330], 24, fill=(245, 246, 250), outline=(225, 228, 238), width=2)
        draw.text((90, 285), "Тамак-аш, товар, дары-дармек...", fill=(140, 145, 160), font=get_font(FONT_REGULAR_PATH, 28), anchor="lm")
        
        # Banner
        draw_rounded_rect(draw, [60, 360, inner_w - 60, 600], 32, fill=(255, 94, 58))
        draw.text((100, 430), "Ыкчам жеткируу!", fill=(255, 255, 255), font=get_font(FONT_BOLD_PATH, 42))
        draw.text((100, 490), "Баткен ичинде 20-35 мунотто", fill=(255, 240, 230), font=get_font(FONT_REGULAR_PATH, 30))
        draw_rounded_rect(draw, [100, 535, 340, 580], 16, fill=(255, 255, 255))
        draw.text((220, 557), "Буйрутма беруу", fill=(255, 94, 58), font=get_font(FONT_BOLD_PATH, 22), anchor="mm")

        # Category Grid
        cats = [
            ("Ресторандар", (255, 245, 235), (255, 120, 50)),
            ("Дукондор", (238, 248, 242), (40, 180, 100)),
            ("Аптека", (238, 245, 255), (50, 120, 255)),
            ("Шаар аралык", (250, 240, 255), (160, 60, 240))
        ]
        grid_y = 640
        w_card = (inner_w - 150) // 2
        for i, (cat_name, bg, fg) in enumerate(cats):
            col = i % 2
            row = i // 2
            x1 = 60 + col * (w_card + 30)
            y1 = grid_y + row * 160
            draw_rounded_rect(draw, [x1, y1, x1 + w_card, y1 + 130], 24, fill=bg, outline=(225, 230, 240), width=1)
            draw.text((x1 + w_card//2, y1 + 65), cat_name, fill=fg, font=get_font(FONT_BOLD_PATH, 30), anchor="mm")

        # Featured Enterprises section
        draw.text((60, 990), "Популярдуу мекемелер", fill=(20, 24, 40), font=get_font(FONT_BOLD_PATH, 36))
        
        # Enterprise Card 1
        draw_rounded_rect(draw, [60, 1050, inner_w - 60, 1200], 28, fill=(255, 255, 255), outline=(230, 233, 245), width=2)
        draw_rounded_rect(draw, [80, 1070, 200, 1180], 20, fill=(255, 235, 235))
        draw.text((140, 1125), "PIZZA", fill=(255, 94, 58), font=get_font(FONT_BOLD_PATH, 26), anchor="mm")
        draw.text((225, 1095), "Dodopizza / Фастфуд", fill=(30, 30, 30), font=get_font(FONT_BOLD_PATH, 32))
        draw_star(draw, 235, 1152, 10, (255, 180, 0))
        draw.text((255, 1142), "4.9 (120+)  *  20-30 мин  *  80 сом", fill=(120, 125, 140), font=get_font(FONT_REGULAR_PATH, 24))

        # Enterprise Card 2
        draw_rounded_rect(draw, [60, 1220, inner_w - 60, 1370], 28, fill=(255, 255, 255), outline=(230, 233, 245), width=2)
        draw_rounded_rect(draw, [80, 1240, 200, 1350], 20, fill=(235, 245, 255))
        draw.text((140, 1295), "COFFEE", fill=(50, 120, 255), font=get_font(FONT_BOLD_PATH, 22), anchor="mm")
        draw.text((225, 1265), "Кофейня & Кондитер", fill=(30, 30, 30), font=get_font(FONT_BOLD_PATH, 32))
        draw_star(draw, 235, 1322, 10, (255, 180, 0))
        draw.text((255, 1312), "4.8 (85+)  *  15-25 мин  *  70 сом", fill=(120, 125, 140), font=get_font(FONT_REGULAR_PATH, 24))

    elif screen_idx == 2:
        draw.text((60, 130), "Заказды козомолдоо", fill=(20, 24, 40), font=get_font(FONT_BOLD_PATH, 40))
        draw.text((60, 180), "Заказ № 48291 - Курьер жолдо", fill=(0, 184, 148), font=get_font(FONT_BOLD_PATH, 28))
        
        # Map simulated area
        draw_rounded_rect(draw, [60, 230, inner_w - 60, 800], 36, fill=(225, 238, 230), outline=(200, 220, 210), width=2)
        draw.line([(100, 350), (inner_w - 100, 420)], fill=(255, 255, 255), width=18)
        draw.line([(inner_w//2, 230), (inner_w//2 + 50, 800)], fill=(255, 255, 255), width=22)
        draw.line([(120, 650), (inner_w - 120, 580)], fill=(255, 255, 255), width=18)
        draw.line([(220, 380), (inner_w//2 + 30, 450), (inner_w//2 + 20, 660), (inner_w - 220, 680)], fill=(108, 99, 255), width=10)
        
        # Destination Pin
        draw.ellipse([inner_w - 250, 650, inner_w - 190, 710], fill=(255, 71, 87))
        draw.ellipse([inner_w - 230, 670, inner_w - 210, 690], fill=(255, 255, 255))
        
        # Courier Live Pin
        draw.ellipse([inner_w//2 - 5, 425, inner_w//2 + 65, 495], fill=(108, 99, 255))
        draw.text((inner_w//2 + 30, 460), "MOTO", fill=(255, 255, 255), font=get_font(FONT_BOLD_PATH, 16), anchor="mm")
        
        # ETA Pill
        draw_rounded_rect(draw, [inner_w//2 - 140, 260, inner_w//2 + 140, 325], 20, fill=(20, 24, 40))
        draw.text((inner_w//2, 292), "Келуу убактысы: 8 мин", fill=(255, 255, 255), font=get_font(FONT_BOLD_PATH, 24), anchor="mm")

        # Bottom Info Sheet
        draw_rounded_rect(draw, [60, 840, inner_w - 60, 1370], 36, fill=(255, 255, 255), outline=(225, 230, 245), width=2)
        
        draw.ellipse([90, 880, 190, 980], fill=(240, 243, 255))
        draw.text((140, 930), "KB", fill=(108, 99, 255), font=get_font(FONT_BOLD_PATH, 36), anchor="mm")
        draw.text((220, 905), "Азамат Бектемиров", fill=(20, 24, 40), font=get_font(FONT_BOLD_PATH, 34))
        draw.text((220, 950), "Рейтинг: 4.95 * 1,420 жеткируу", fill=(110, 115, 130), font=get_font(FONT_REGULAR_PATH, 24))
        
        # Action Buttons
        draw_rounded_rect(draw, [inner_w - 240, 895, inner_w - 170, 965], 20, fill=(238, 248, 242))
        draw.text((inner_w - 205, 930), "TEL", fill=(0, 184, 148), font=get_font(FONT_BOLD_PATH, 20), anchor="mm")
        draw_rounded_rect(draw, [inner_w - 150, 895, inner_w - 80, 965], 20, fill=(240, 243, 255))
        draw.text((inner_w - 115, 930), "CHAT", fill=(108, 99, 255), font=get_font(FONT_BOLD_PATH, 18), anchor="mm")

        steps = [
            ("[V] Буйрутма кабыл алынды", True),
            ("[V] Даярдалып бутуп, тапшырылды", True),
            ("[>] Курьер сизди коздой баратат", True),
            ("[ ] Жеткирилип берилди", False)
        ]
        step_y = 1030
        for text, done in steps:
            col = (0, 184, 148) if done else (180, 185, 200)
            draw.text((100, step_y), text, fill=col, font=get_font(FONT_BOLD_PATH if done else FONT_REGULAR_PATH, 28))
            step_y += 65

    elif screen_idx == 3:
        draw.text((60, 130), "Кош келиниз!", fill=(20, 24, 40), font=get_font(FONT_BOLD_PATH, 44))
        draw.text((60, 190), "Колдонмону колдонуу ролунузду танданыз:", fill=(110, 115, 130), font=get_font(FONT_REGULAR_PATH, 28))
        
        roles = [
            ("USER", "Кардар (Колдонуучу)", "Тамак-аш, дукон товарларын буйрутма кылуу", (245, 247, 255), (108, 99, 255)),
            ("COURIER", "Курьер", "Заказдарды жеткирип, кун сайын киреше табуу", (238, 250, 245), (0, 184, 148)),
            ("STORE", "Мекеме / Ишкана", "Ресторан, дукон менюсун жана заказдарды башкаруу", (255, 245, 245), (255, 107, 107))
        ]
        
        y_pos = 260
        for badge, title, desc, bg, accent in roles:
            draw_rounded_rect(draw, [60, y_pos, inner_w - 60, y_pos + 260], 32, fill=bg, outline=accent, width=2)
            draw_rounded_rect(draw, [90, y_pos + 40, 200, y_pos + 150], 24, fill=(255, 255, 255))
            draw.text((145, y_pos + 95), badge, fill=accent, font=get_font(FONT_BOLD_PATH, 22), anchor="mm")
            
            draw.text((230, y_pos + 60), title, fill=(20, 24, 40), font=get_font(FONT_BOLD_PATH, 34))
            draw.text((230, y_pos + 115), desc, fill=(110, 115, 130), font=get_font(FONT_REGULAR_PATH, 24))
            
            draw_rounded_rect(draw, [230, y_pos + 175, inner_w - 90, y_pos + 230], 16, fill=accent)
            draw.text(((230 + inner_w - 90)//2, y_pos + 202), "Улантуу  ->", fill=(255, 255, 255), font=get_font(FONT_BOLD_PATH, 24), anchor="mm")
            
            y_pos += 300

        draw.text((inner_w//2, y_pos + 70), "Каттоодон отконсузбу?  Кируу", fill=(108, 99, 255), font=get_font(FONT_BOLD_PATH, 30), anchor="mm")

    elif screen_idx == 4:
        draw.text((60, 130), "Жеке кабинет жана капчык", fill=(20, 24, 40), font=get_font(FONT_BOLD_PATH, 40))
        draw.text((60, 180), "Толомдор, баланс жана тарых", fill=(120, 125, 140), font=sub_font)
        
        # Balance Card
        draw_rounded_rect(draw, [60, 240, inner_w - 60, 520], 36, fill=(20, 24, 40))
        draw.text((100, 290), "Капчык балансы", fill=(180, 190, 210), font=get_font(FONT_REGULAR_PATH, 28))
        draw.text((100, 360), "12,450 сом", fill=(255, 255, 255), font=get_font(FONT_BOLD_PATH, 54))
        
        # Quick action pills
        draw_rounded_rect(draw, [100, 420, 340, 480], 20, fill=(0, 184, 148))
        draw.text((220, 450), "+ Толуктоо", fill=(255, 255, 255), font=get_font(FONT_BOLD_PATH, 26), anchor="mm")
        
        draw_rounded_rect(draw, [370, 420, 610, 480], 20, fill=(108, 99, 255))
        draw.text((490, 450), "Толом QR", fill=(255, 255, 255), font=get_font(FONT_BOLD_PATH, 26), anchor="mm")

        # Payment Methods
        draw.text((60, 570), "Колдоого алынган толомдор", fill=(20, 24, 40), font=get_font(FONT_BOLD_PATH, 34))
        pays = ["Mbank QR", "О!Деньги", "Элкарт / Visa", "Накталай"]
        p_x = 60
        for p in pays:
            draw_rounded_rect(draw, [p_x, 620, p_x + 190, 690], 18, fill=(245, 247, 252), outline=(225, 230, 242), width=1)
            draw.text((p_x + 95, 655), p, fill=(40, 45, 60), font=get_font(FONT_BOLD_PATH, 22), anchor="mm")
            p_x += 210

        # Menu List
        menu_items = [
            ("HIST", "Буйрутмалардын тарыхы", "Бардык аткарылган жеткируулор"),
            ("SAFE", "Коопсуздук жана саясат", "Купуялуулук саясаты, маалымат коргоо"),
            ("LANG", "Колдонмонун тили", "Кыргызча / Русский"),
            ("HELP", "24/7 Колдоо кызматы", "WhatsApp & Telegram туз байланыш")
        ]
        
        m_y = 730
        for tag, title, desc in menu_items:
            draw_rounded_rect(draw, [60, m_y, inner_w - 60, m_y + 130], 24, fill=(255, 255, 255), outline=(230, 235, 245), width=2)
            draw_rounded_rect(draw, [80, m_y + 20, 160, m_y + 110], 18, fill=(245, 246, 252))
            draw.text((120, m_y + 65), tag, fill=(108, 99, 255), font=get_font(FONT_BOLD_PATH, 20), anchor="mm")
            
            draw.text((190, m_y + 35), title, fill=(20, 24, 40), font=get_font(FONT_BOLD_PATH, 28))
            draw.text((190, m_y + 80), desc, fill=(130, 135, 150), font=get_font(FONT_REGULAR_PATH, 22))
            draw.text((inner_w - 100, m_y + 65), "->", fill=(180, 185, 200), font=get_font(FONT_BOLD_PATH, 26), anchor="mm")
            
            m_y += 150

    return ui

def generate_screenshots():
    slides_meta = [
        {
            "badge": "БАТКЕН ЭКСПРЕСС",
            "title": "Тез жана ишенимдуу жеткируу",
            "subtitle": "Баткен шаарында жана райондорунда ыкчам кызмат",
            "top_color": (32, 28, 70),
            "bottom_color": (15, 14, 35),
            "accent": (255, 107, 0)
        },
        {
            "badge": "МЕНЮ ЖАНА КАТАЛОГ",
            "title": "Ресторан, дукон жана аптекалар",
            "subtitle": "Суйуктуу тамак-аш, товарлар жана дарыларды буйрутма кылыныз",
            "top_color": (25, 45, 65),
            "bottom_color": (12, 22, 35),
            "accent": (0, 206, 201)
        },
        {
            "badge": "ОНЛАЙН КАРТА",
            "title": "Курьерди картада туз корунуз",
            "subtitle": "Заказдын статусу жана келуу убактысы секунда сайын жаныланат",
            "top_color": (20, 55, 45),
            "bottom_color": (10, 30, 25),
            "accent": (0, 184, 148)
        },
        {
            "badge": "БАРДЫК РОЛДОР БИР ЖЕРДЕ",
            "title": "Кардар, Курьер же Ишкана",
            "subtitle": "Озунузго ылайыктуу режимди тандап, оной иштениз",
            "top_color": (60, 30, 40),
            "bottom_color": (30, 15, 20),
            "accent": (255, 118, 117)
        },
        {
            "badge": "КООПСУЗДУК ЖАНА ЫНГАЙЛУУЛУК",
            "title": "Капчык, QR толом жана 24/7 колдоо",
            "subtitle": "Ынгайлуу онлайн толомдор жана кардарларды колдоо кызматы",
            "top_color": (28, 35, 60),
            "bottom_color": (14, 18, 32),
            "accent": (108, 99, 255)
        }
    ]

    configs = [
        {
            "folder": os.path.join(ASSETS_DIR, 'screenshots_6.7_inch'),
            "W": 1290,
            "H": 2796,
            "phone_w": 1050,
            "phone_h": 2050,
            "phone_y": 700,
            "title_y": 280,
            "badge_y": 190
        },
        {
            "folder": os.path.join(ASSETS_DIR, 'screenshots_6.5_inch'),
            "W": 1242,
            "H": 2688,
            "phone_w": 1000,
            "phone_h": 1950,
            "phone_y": 680,
            "title_y": 270,
            "badge_y": 180
        }
    ]

    for cfg in configs:
        W = cfg["W"]
        H = cfg["H"]
        phone_w = cfg["phone_w"]
        phone_h = cfg["phone_h"]
        phone_y = cfg["phone_y"]
        folder = cfg["folder"]
        
        for idx, meta in enumerate(slides_meta):
            bg = create_gradient(W, H, meta["top_color"], meta["bottom_color"])
            draw = ImageDraw.Draw(bg)
            
            badge_font = get_font(FONT_BOLD_PATH, 28)
            badge_text = meta["badge"]
            badge_bbox = draw.textbbox((0, 0), badge_text, font=badge_font)
            bw = badge_bbox[2] - badge_bbox[0] + 50
            bh = 46
            bx = (W - bw) // 2
            by = cfg["badge_y"]
            draw_rounded_rect(draw, [bx, by, bx + bw, by + bh], 23, fill=(255, 255, 255, 40), outline=meta["accent"], width=2)
            draw.text((W // 2, by + bh // 2), badge_text, fill=meta["accent"], font=badge_font, anchor="mm")
            
            title_font = get_font(FONT_BOLD_PATH, 68)
            draw.text((W // 2, cfg["title_y"]), meta["title"], fill=(255, 255, 255), font=title_font, anchor="mm", align="center")
            
            sub_font = get_font(FONT_REGULAR_PATH, 34)
            draw.text((W // 2, cfg["title_y"] + 90), meta["subtitle"], fill=(200, 210, 225), font=sub_font, anchor="mm", align="center")
            
            px = (W - phone_w) // 2
            py = phone_y
            
            draw_rounded_rect(draw, [px - 14, py - 14, px + phone_w + 14, py + phone_h + 14], 74, fill=(40, 45, 55), outline=(90, 95, 110), width=4)
            draw_rounded_rect(draw, [px, py, px + phone_w, py + phone_h], 60, fill=(0, 0, 0))
            
            inner_w = phone_w - 20
            inner_h = phone_h - 20
            ui_content = build_screenshot_card(idx, inner_w, inner_h)
            
            mask = Image.new('L', (inner_w, inner_h), 0)
            mask_draw = ImageDraw.Draw(mask)
            mask_draw.rounded_rectangle([0, 0, inner_w, inner_h], radius=50, fill=255)
            
            bg.paste(ui_content, (px + 10, py + 10), mask)
            
            out_file = os.path.join(folder, f"screenshot_{idx + 1}_{W}x{H}.png")
            bg.save(out_file, 'PNG', optimize=True)
            print(f"Generated screenshot: {out_file}")

def generate_marketing_graphic():
    W = 1024
    H = 500
    bg = create_gradient(W, H, (30, 25, 65), (15, 12, 35))
    draw = ImageDraw.Draw(bg)
    
    icon_path = os.path.join(ASSETS_DIR, 'icon', 'AppStore_Icon_1024x1024.png')
    if os.path.exists(icon_path):
        icon_img = Image.open(icon_path).convert('RGBA').resize((240, 240), Image.Resampling.LANCZOS)
        icon_mask = Image.new('L', (240, 240), 0)
        ImageDraw.Draw(icon_mask).rounded_rectangle([0, 0, 240, 240], radius=54, fill=255)
        bg.paste(icon_img, (80, 130), icon_mask)
    
    draw.text((360, 170), "БАТКЕН ЭКСПРЕСС", fill=(255, 255, 255), font=get_font(FONT_BOLD_PATH, 44))
    draw.text((360, 235), "БатЖеткирет - Ыкчам жеткируу кызматы", fill=(255, 107, 0), font=get_font(FONT_BOLD_PATH, 26))
    draw.text((360, 285), "Тамак-аш, дукон товарлары жана шаар аралык жеткируу", fill=(200, 205, 220), font=get_font(FONT_REGULAR_PATH, 22))
    
    draw_rounded_rect(draw, [360, 340, 520, 390], 18, fill=(0, 184, 148))
    draw.text((440, 365), "App Store", fill=(255, 255, 255), font=get_font(FONT_BOLD_PATH, 22), anchor="mm")
    
    draw_rounded_rect(draw, [540, 340, 720, 390], 18, fill=(108, 99, 255))
    draw.text((630, 365), "20-35 мунот", fill=(255, 255, 255), font=get_font(FONT_BOLD_PATH, 22), anchor="mm")
    
    out_file = os.path.join(ASSETS_DIR, 'marketing', 'Feature_Graphic_1024x500.png')
    bg.save(out_file, 'PNG', optimize=True)
    print(f"Generated Feature Graphic: {out_file}")

if __name__ == '__main__':
    print("🎨 Starting App Store asset generation...")
    generate_icon()
    generate_screenshots()
    generate_marketing_graphic()
    print("✨ All App Store assets successfully generated!")
