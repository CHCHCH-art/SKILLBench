# Urdu Language Support Examples

## Example 1: next-intl Configuration

```typescript
// frontend/i18n.ts
import { getRequestConfig } from 'next-intl/server';
import { notFound } from 'next/navigation';

export const locales = ['en', 'ur'] as const;
export type Locale = (typeof locales)[number];

export default getRequestConfig(async ({ locale }) => {
  if (!locales.includes(locale as Locale)) {
    notFound();
  }

  return {
    messages: (await import(`./messages/${locale}.json`)).default,
    timeZone: 'Asia/Karachi',
    now: new Date(),
  };
});
```

## Example 2: Middleware for Locale Detection

```typescript
// frontend/middleware.ts
import createMiddleware from 'next-intl/middleware';
import { locales } from './i18n';

export default createMiddleware({
  locales,
  defaultLocale: 'en',
  localePrefix: 'as-needed',
  localeDetection: true,
});

export const config = {
  matcher: [
    '/((?!api|_next|_vercel|.*\\..*).*)',
    '/',
  ],
};
```

## Example 3: Complete Urdu Translations

```json
// frontend/messages/ur.json
{
  "metadata": {
    "title": "ایوولیوشن ٹوڈو - آپ کا ذاتی ٹاسک مینیجر",
    "description": "AI سے چلنے والا ٹاسک مینجمنٹ ایپلیکیشن"
  },
  "common": {
    "appName": "ایوولیوشن ٹوڈو",
    "loading": "لوڈ ہو رہا ہے...",
    "save": "محفوظ کریں",
    "cancel": "منسوخ کریں",
    "delete": "حذف کریں",
    "edit": "ترمیم کریں",
    "create": "بنائیں",
    "update": "اپڈیٹ کریں",
    "search": "تلاش کریں",
    "filter": "فلٹر",
    "sort": "ترتیب دیں",
    "actions": "کارروائیاں",
    "confirm": "تصدیق کریں",
    "yes": "ہاں",
    "no": "نہیں",
    "back": "واپس",
    "next": "اگلا",
    "previous": "پچھلا",
    "close": "بند کریں",
    "open": "کھولیں",
    "more": "مزید",
    "less": "کم",
    "all": "سب",
    "none": "کوئی نہیں",
    "error": "خرابی",
    "success": "کامیابی",
    "warning": "انتباہ",
    "info": "معلومات"
  },
  "auth": {
    "login": "لاگ ان",
    "signup": "سائن اپ",
    "logout": "لاگ آؤٹ",
    "email": "ای میل",
    "password": "پاس ورڈ",
    "confirmPassword": "پاس ورڈ کی تصدیق کریں",
    "name": "نام",
    "forgotPassword": "پاس ورڈ بھول گئے؟",
    "resetPassword": "پاس ورڈ دوبارہ ترتیب دیں",
    "rememberMe": "مجھے یاد رکھیں",
    "dontHaveAccount": "اکاؤنٹ نہیں ہے؟",
    "alreadyHaveAccount": "پہلے سے اکاؤنٹ ہے؟",
    "loginSuccess": "خوش آمدید!",
    "logoutSuccess": "کامیابی سے لاگ آؤٹ ہو گئے",
    "signupSuccess": "اکاؤنٹ کامیابی سے بن گیا",
    "invalidCredentials": "غلط ای میل یا پاس ورڈ"
  },
  "tasks": {
    "title": "کام",
    "myTasks": "میرے کام",
    "newTask": "نیا کام",
    "addTask": "کام شامل کریں",
    "editTask": "کام میں ترمیم کریں",
    "deleteTask": "کام حذف کریں",
    "viewTask": "کام دیکھیں",
    "taskTitle": "کام کا عنوان",
    "description": "تفصیل",
    "priority": "ترجیح",
    "dueDate": "آخری تاریخ",
    "status": "حیثیت",
    "tags": "ٹیگز",
    "reminder": "یاد دہانی",
    "recurring": "بار بار ہونے والا",
    "createdAt": "بنانے کی تاریخ",
    "updatedAt": "اپڈیٹ کی تاریخ",
    "completedAt": "مکمل ہونے کی تاریخ",
    "priorities": {
      "low": "کم",
      "medium": "درمیانی",
      "high": "زیادہ"
    },
    "statuses": {
      "pending": "زیر التواء",
      "inProgress": "جاری",
      "completed": "مکمل"
    },
    "recurrence": {
      "none": "کوئی نہیں",
      "daily": "روزانہ",
      "weekly": "ہفتہ وار",
      "monthly": "ماہانہ"
    },
    "noTasks": "کوئی کام نہیں ملا",
    "completedTasks": "مکمل شدہ کام",
    "pendingTasks": "زیر التواء کام",
    "todaysTasks": "آج کے کام",
    "overdueTasks": "مدت ختم شدہ کام",
    "searchPlaceholder": "کام تلاش کریں...",
    "filterByStatus": "حیثیت سے فلٹر کریں",
    "filterByPriority": "ترجیح سے فلٹر کریں",
    "filterByTag": "ٹیگ سے فلٹر کریں",
    "sortBy": "ترتیب",
    "clearFilters": "فلٹرز صاف کریں",
    "taskCreated": "کام کامیابی سے بنایا گیا",
    "taskUpdated": "کام کامیابی سے اپڈیٹ ہو گیا",
    "taskDeleted": "کام کامیابی سے حذف ہو گیا",
    "taskCompleted": "کام مکمل!",
    "confirmDelete": "کیا آپ واقعی اس کام کو حذف کرنا چاہتے ہیں؟"
  },
  "tags": {
    "title": "ٹیگز",
    "newTag": "نیا ٹیگ",
    "tagName": "ٹیگ کا نام",
    "tagColor": "ٹیگ کا رنگ",
    "noTags": "کوئی ٹیگ نہیں",
    "manageTags": "ٹیگز کا انتظام کریں",
    "addToTask": "کام میں شامل کریں",
    "removeFromTask": "کام سے ہٹائیں"
  },
  "reminders": {
    "title": "یاد دہانیاں",
    "setReminder": "یاد دہانی مقرر کریں",
    "reminderTime": "یاد دہانی کا وقت",
    "reminderMessage": "یاد دہانی کا پیغام",
    "noReminders": "کوئی یاد دہانی نہیں",
    "reminderSet": "یاد دہانی مقرر ہو گئی",
    "reminderDeleted": "یاد دہانی حذف ہو گئی"
  },
  "chat": {
    "title": "AI معاون",
    "placeholder": "اپنے کاموں کے بارے میں کچھ بھی پوچھیں...",
    "send": "بھیجیں",
    "thinking": "سوچ رہا ہوں...",
    "newConversation": "نئی گفتگو",
    "conversations": "گفتگو",
    "noConversations": "کوئی گفتگو نہیں",
    "deleteConversation": "گفتگو حذف کریں",
    "suggestions": {
      "createTask": "ایک نیا کام بنائیں",
      "listTasks": "میرے کام دکھائیں",
      "completedToday": "آج کیا مکمل ہوا؟",
      "highPriority": "اعلی ترجیح والے کام"
    }
  },
  "dashboard": {
    "title": "ڈیش بورڈ",
    "welcome": "خوش آمدید",
    "overview": "جائزہ",
    "quickStats": "فوری اعدادوشمار",
    "totalTasks": "کل کام",
    "completedTasks": "مکمل کام",
    "pendingTasks": "زیر التواء کام",
    "overdueTasks": "مدت ختم شدہ",
    "recentActivity": "حالیہ سرگرمی",
    "upcomingDeadlines": "آنے والی آخری تاریخیں"
  },
  "settings": {
    "title": "ترتیبات",
    "profile": "پروفائل",
    "language": "زبان",
    "theme": "تھیم",
    "notifications": "اطلاعات",
    "account": "اکاؤنٹ",
    "preferences": "ترجیحات",
    "themes": {
      "light": "روشن",
      "dark": "اندھیرا",
      "system": "سسٹم"
    },
    "languages": {
      "en": "English",
      "ur": "اردو"
    },
    "saveChanges": "تبدیلیاں محفوظ کریں",
    "changesSaved": "تبدیلیاں محفوظ ہو گئیں"
  },
  "errors": {
    "generic": "کچھ غلط ہو گیا",
    "networkError": "نیٹ ورک کی خرابی",
    "notFound": "نہیں ملا",
    "unauthorized": "غیر مجاز رسائی",
    "forbidden": "رسائی ممنوع",
    "serverError": "سرور کی خرابی",
    "validationError": "توثیق کی خرابی",
    "tryAgain": "دوبارہ کوشش کریں"
  },
  "time": {
    "today": "آج",
    "yesterday": "کل",
    "tomorrow": "کل",
    "thisWeek": "اس ہفتے",
    "nextWeek": "اگلے ہفتے",
    "thisMonth": "اس مہینے",
    "ago": "پہلے",
    "in": "میں",
    "minutes": "منٹ",
    "hours": "گھنٹے",
    "days": "دن",
    "weeks": "ہفتے",
    "months": "مہینے"
  }
}
```

## Example 4: RTL Provider Component

```tsx
// frontend/components/providers/rtl-provider.tsx
"use client";

import { useLocale } from "next-intl";
import { useEffect, ReactNode } from "react";

interface RTLProviderProps {
  children: ReactNode;
}

export function RTLProvider({ children }: RTLProviderProps) {
  const locale = useLocale();
  const isRTL = locale === "ur";

  useEffect(() => {
    // Set document direction
    document.documentElement.dir = isRTL ? "rtl" : "ltr";
    document.documentElement.lang = locale;

    // Add RTL class for Tailwind
    if (isRTL) {
      document.documentElement.classList.add("rtl");
    } else {
      document.documentElement.classList.remove("rtl");
    }

    // Set font family for Urdu
    if (isRTL) {
      document.body.classList.add("font-urdu");
    } else {
      document.body.classList.remove("font-urdu");
    }
  }, [locale, isRTL]);

  return <>{children}</>;
}
```

## Example 5: Language Switcher Component

```tsx
// frontend/components/language-switcher.tsx
"use client";

import { useLocale, useTranslations } from "next-intl";
import { useRouter, usePathname } from "next/navigation";
import { useState, useTransition } from "react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";
import { Globe, Check } from "lucide-react";

const languages = [
  { code: "en", name: "English", nativeName: "English", flag: "🇺🇸" },
  { code: "ur", name: "Urdu", nativeName: "اردو", flag: "🇵🇰" },
];

export function LanguageSwitcher() {
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();
  const t = useTranslations("settings");
  const [isPending, startTransition] = useTransition();
  const [isOpen, setIsOpen] = useState(false);

  const currentLanguage = languages.find((l) => l.code === locale);

  const handleLanguageChange = (newLocale: string) => {
    setIsOpen(false);
    startTransition(() => {
      // Remove current locale prefix and navigate to new locale
      const pathWithoutLocale = pathname.replace(/^\/(en|ur)/, "");
      router.push(`/${newLocale}${pathWithoutLocale || "/"}`);
    });
  };

  return (
    <DropdownMenu open={isOpen} onOpenChange={setIsOpen}>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          size="sm"
          disabled={isPending}
          className="gap-2"
        >
          <Globe className="h-4 w-4" />
          <span className="hidden sm:inline">{currentLanguage?.nativeName}</span>
          <span className="sm:hidden">{currentLanguage?.flag}</span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-48">
        {languages.map((language) => (
          <DropdownMenuItem
            key={language.code}
            onClick={() => handleLanguageChange(language.code)}
            className="flex items-center justify-between cursor-pointer"
          >
            <span className="flex items-center gap-2">
              <span>{language.flag}</span>
              <span>{language.nativeName}</span>
            </span>
            {locale === language.code && (
              <Check className="h-4 w-4 text-primary" />
            )}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
```

## Example 6: AI Agent Urdu Support

```python
# backend/src/agents/prompts.py

SYSTEM_PROMPT_EN = """
You are a helpful AI assistant that helps users manage their tasks.

You can:
- Create new tasks
- List tasks
- Complete tasks
- Delete tasks
- Edit tasks
- Set reminders
- Manage tags

Always be helpful and concise in your responses.
"""

SYSTEM_PROMPT_UR = """
آپ ایک مددگار AI اسسٹنٹ ہیں جو صارفین کو ان کے کاموں کا انتظام کرنے میں مدد کرتا ہے۔

آپ یہ کر سکتے ہیں:
- نئے کام بنائیں
- کاموں کی فہرست دیکھیں
- کام مکمل کریں
- کام حذف کریں
- کاموں میں ترمیم کریں
- یاد دہانیاں مقرر کریں
- ٹیگز کا انتظام کریں

ہمیشہ مددگار اور مختصر جوابات دیں۔ اردو میں جواب دیں جب صارف اردو میں پوچھے۔
"""

def get_system_prompt(language: str = "en") -> str:
    """Get system prompt based on language."""
    prompts = {
        "en": SYSTEM_PROMPT_EN,
        "ur": SYSTEM_PROMPT_UR,
    }
    return prompts.get(language, SYSTEM_PROMPT_EN)
```

## Example 7: Language Detection Service

```python
# backend/src/services/language_service.py
from langdetect import detect, DetectorFactory
from typing import Literal

# Make detection deterministic
DetectorFactory.seed = 0

LanguageCode = Literal["en", "ur"]

class LanguageService:
    """Service for detecting and managing languages."""

    @staticmethod
    def detect_language(text: str) -> LanguageCode:
        """Detect the language of the given text."""
        try:
            detected = detect(text)
            # Map detected language to supported languages
            if detected == "ur":
                return "ur"
            return "en"
        except Exception:
            return "en"

    @staticmethod
    def is_urdu(text: str) -> bool:
        """Check if the text is in Urdu."""
        return LanguageService.detect_language(text) == "ur"

    @staticmethod
    def get_direction(language: LanguageCode) -> Literal["ltr", "rtl"]:
        """Get text direction for a language."""
        return "rtl" if language == "ur" else "ltr"

# Usage in agent
from .language_service import LanguageService

async def run_agent(user_message: str, user_id: str, language: str = None):
    """Run AI agent with language support."""
    # Auto-detect language if not specified
    if language is None:
        language = LanguageService.detect_language(user_message)

    system_prompt = get_system_prompt(language)

    # Create agent with language-specific prompt
    agent = Agent(
        name="todo_assistant",
        instructions=system_prompt,
        model="gemini/gemini-2.0-flash",
        tools=[...],
    )

    response = await Runner.run(agent, user_message)
    return response
```

## Example 8: Tailwind RTL Configuration

```typescript
// frontend/tailwind.config.ts
import type { Config } from "tailwindcss";
import rtl from "tailwindcss-rtl";

const config: Config = {
  darkMode: ["class"],
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./lib/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ["var(--font-inter)", "sans-serif"],
        urdu: ["var(--font-noto-nastaliq)", "serif"],
      },
      // RTL-aware spacing
      spacing: {
        // Use logical properties
      },
    },
  },
  plugins: [
    rtl,
    // Plugin to add RTL variants
    function({ addUtilities }) {
      addUtilities({
        '.text-start': {
          'text-align': 'start',
        },
        '.text-end': {
          'text-align': 'end',
        },
        '.ms-auto': {
          'margin-inline-start': 'auto',
        },
        '.me-auto': {
          'margin-inline-end': 'auto',
        },
        '.ps-4': {
          'padding-inline-start': '1rem',
        },
        '.pe-4': {
          'padding-inline-end': '1rem',
        },
      });
    },
  ],
};

export default config;
```

## Example 9: Root Layout with Fonts

```tsx
// frontend/app/[locale]/layout.tsx
import { Inter } from "next/font/google";
import { Noto_Nastaliq_Urdu } from "next/font/google";
import { notFound } from "next/navigation";
import { NextIntlClientProvider } from "next-intl";
import { getMessages } from "next-intl/server";
import { locales } from "@/i18n";
import { RTLProvider } from "@/components/providers/rtl-provider";
import { ThemeProvider } from "@/components/providers/theme-provider";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

const notoNastaliq = Noto_Nastaliq_Urdu({
  subsets: ["arabic"],
  variable: "--font-noto-nastaliq",
  weight: ["400", "700"],
  display: "swap",
});

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export default async function LocaleLayout({
  children,
  params: { locale },
}: {
  children: React.ReactNode;
  params: { locale: string };
}) {
  if (!locales.includes(locale as any)) {
    notFound();
  }

  const messages = await getMessages();

  return (
    <html lang={locale} suppressHydrationWarning>
      <body className={`${inter.variable} ${notoNastaliq.variable} font-sans`}>
        <NextIntlClientProvider messages={messages}>
          <ThemeProvider>
            <RTLProvider>{children}</RTLProvider>
          </ThemeProvider>
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
```
