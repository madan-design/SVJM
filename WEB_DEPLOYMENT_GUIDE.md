# SVJM Quote Generator - Web Deployment Guide

## 📁 Built Files Location
Your web app files are in: `build/web/`

## 🌐 Deployment Options

### Option 1: Firebase Hosting (Recommended)
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project
firebase init hosting

# Deploy
firebase deploy
```

### Option 2: Netlify (Easiest)
1. Go to https://netlify.com
2. Drag the entire `build/web` folder to the deployment area
3. Get your live URL instantly!

### Option 3: Vercel
1. Go to https://vercel.com
2. Click "New Project"
3. Upload the `build/web` folder
4. Deploy instantly!

### Option 4: GitHub Pages
1. Create a new GitHub repository
2. Upload all files from `build/web` to the repository
3. Go to Settings > Pages
4. Select source branch and deploy

## 🔧 Important Notes

### Environment Variables
Make sure your Supabase credentials in `lib/config/.env` are set for production:
- SUPABASE_URL=your_production_url
- SUPABASE_ANON_KEY=your_production_key

### HTTPS Required
- Most hosting platforms provide HTTPS automatically
- Required for PWA features and secure authentication

### Custom Domain
- Most platforms support custom domains
- Update your domain DNS to point to the hosting platform

## 📱 Sharing Your Web App

Once deployed, you can share your web app URL with your organization:
- **Desktop**: Works in all modern browsers
- **Mobile**: Works as a responsive web app
- **PWA**: Can be installed on devices like a native app

## 🔄 Updates
To update your web app:
1. Make changes to your Flutter code
2. Run: `flutter build web --release`
3. Re-deploy the updated `build/web` folder

## 🎯 Access URLs
After deployment, your team can access the app at:
- Firebase: `https://your-project.web.app`
- Netlify: `https://your-app.netlify.app`
- Vercel: `https://your-app.vercel.app`
- Custom: `https://yourdomain.com`

## 📊 Features Available in Web Version
✅ All core business features
✅ Drag & drop file uploads
✅ PDF generation and viewing
✅ User authentication
✅ Real-time data sync
✅ Responsive design
✅ Cross-platform compatibility