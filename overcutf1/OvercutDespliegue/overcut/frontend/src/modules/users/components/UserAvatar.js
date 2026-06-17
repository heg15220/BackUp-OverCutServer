// UserAvatar.js
import React from "react";
import "./UserAvatar.css";

const colors = [
  "#FF6B6B", "#FFD93D", "#6BCB77", "#4D96FF", "#845EC2", "#F9A826", "#00C9A7"
];

const getColorFromName = (name) => {
  const charCode = name.charCodeAt(0);
  return colors[charCode % colors.length];
};

const UserAvatar = ({ image, userName, size = 40 }) => {
  const backgroundColor = getColorFromName(userName);
  const firstLetter = userName.charAt(0).toUpperCase();

  return (
    <div
      className="user-avatar-container"
      style={{ width: size, height: size }}
      aria-label={userName}
      title={userName}
    >
      {image ? (
        <img
          src={`data:image/*;base64,${image}`}
          alt={userName}
          className="user-avatar-img"
        />
      ) : (
        <div
          className="user-avatar-letter"
          style={{ backgroundColor, fontSize: size / 2 }}
        >
          {firstLetter}
        </div>
      )}
    </div>
  );
};

export default UserAvatar;
