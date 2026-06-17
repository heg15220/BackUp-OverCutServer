# ---------- Build OverCut frontend ----------
FROM node:22 AS overcut-fe
WORKDIR /src
COPY ../../overcut/frontend/package*.json ./
RUN npm ci --legacy-peer-deps
COPY ../../overcut/frontend ./
ENV NODE_ENV=production
RUN npm run build || npm run build:prod || echo "built"
RUN ["node","-e","const fs=require('fs'); const path=require('path'); const src='build', dst='dist'; const copy=(s,d)=>{ fs.mkdirSync(d,{recursive:true}); for(const ent of fs.readdirSync(s,{withFileTypes:true})){ const sp=path.join(s,ent.name), dp=path.join(d,ent.name); if(ent.isDirectory()) copy(sp,dp); else if(ent.isSymbolicLink()) fs.symlinkSync(fs.readlinkSync(sp),dp); else fs.copyFileSync(sp,dp); } }; if(fs.existsSync(src)){ fs.rmSync(dst,{recursive:true,force:true}); copy(src,dst); fs.rmSync(src,{recursive:true,force:true}); }"]

# ---------- Build F1Hub frontend ----------
FROM node:22 AS f1hub-fe
WORKDIR /src
COPY ../../f1Hub/frontend/package*.json ./
RUN npm ci --legacy-peer-deps
COPY ../../f1Hub/frontend ./
ENV NODE_ENV=production
RUN npm run build || npm run build:prod || echo "built"
RUN ["node","-e","const fs=require('fs'); const path=require('path'); const src='build', dst='dist'; const copy=(s,d)=>{ fs.mkdirSync(d,{recursive:true}); for(const ent of fs.readdirSync(s,{withFileTypes:true})){ const sp=path.join(s,ent.name), dp=path.join(d,ent.name); if(ent.isDirectory()) copy(sp,dp); else if(ent.isSymbolicLink()) fs.symlinkSync(fs.readlinkSync(sp),dp); else fs.copyFileSync(sp,dp); } }; if(fs.existsSync(src)){ fs.rmSync(dst,{recursive:true,force:true}); copy(src,dst); fs.rmSync(src,{recursive:true,force:true}); }"]

# ---------- Build OverCutPredictions frontend ----------
FROM node:22 AS predictions-fe
WORKDIR /src
COPY ../../overcutPredictions/frontend/package*.json ./
RUN npm install --legacy-peer-deps
COPY ../../overcutPredictions/frontend ./
ENV NODE_ENV=production
ENV REACT_APP_OVERCUT_URL=/
RUN npm run build || npm run build:prod || echo "built"
RUN ["node","-e","const fs=require('fs'); const path=require('path'); const src='build', dst='dist'; const copy=(s,d)=>{ fs.mkdirSync(d,{recursive:true}); for(const ent of fs.readdirSync(s,{withFileTypes:true})){ const sp=path.join(s,ent.name), dp=path.join(d,ent.name); if(ent.isDirectory()) copy(sp,dp); else if(ent.isSymbolicLink()) fs.symlinkSync(fs.readlinkSync(sp),dp); else fs.copyFileSync(sp,dp); } }; if(fs.existsSync(src)){ fs.rmSync(dst,{recursive:true,force:true}); copy(src,dst); fs.rmSync(src,{recursive:true,force:true}); }"]

# ---------- Nginx ----------
FROM nginx:1.27-alpine

RUN mkdir -p /usr/share/nginx/html/overcut \
             /usr/share/nginx/html/f1hub \
             /usr/share/nginx/html/overcutPredictions \
             /var/www/certbot \
 && rm -rf /usr/share/nginx/html/overcut/* \
          /usr/share/nginx/html/f1hub/* \
          /usr/share/nginx/html/overcutPredictions/*

COPY --from=overcut-fe      /src/dist/ /usr/share/nginx/html/overcut/
COPY --from=f1hub-fe        /src/dist/ /usr/share/nginx/html/f1hub/
COPY --from=predictions-fe  /src/dist/ /usr/share/nginx/html/overcutPredictions/

COPY ./deploy/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
COPY ./deploy/nginx/nginx.conf /etc/nginx/nginx.conf

VOLUME ["/etc/letsencrypt","/var/www/certbot"]
EXPOSE 80 443
