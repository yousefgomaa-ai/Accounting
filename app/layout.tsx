import type { Metadata } from 'next';
import './globals.css';
export const metadata:Metadata={title:'ميزان | مساحة المحاسب والطالب',description:'دفاتر وقوائم مالية محفوظة، قيود قابلة للمراجعة، وأدوات ودروس عربية موثقة بمراجع IFRS.',icons:{icon:'/favicon.svg'}};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="ar" dir="rtl"><body>{children}</body></html>}
