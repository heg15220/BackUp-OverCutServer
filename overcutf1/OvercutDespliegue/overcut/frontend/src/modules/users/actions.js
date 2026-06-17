import * as actionTypes from './actionTypes';
import backend from '../../backend';

const signUpCompleted = authenticatedUser => ({
    type: actionTypes.SIGN_UP_COMPLETED,
    authenticatedUser
});

const getUserPointsCompleted = (points) => ({
    type:actionTypes.GET_USER_POINTS_COMPLETED,
    points
});

export const signUp = (user, onSuccess, onErrors, reauthenticationCallback) => dispatch =>
    backend.userService.signUp(user,
        () => {
            onSuccess();
        },
        onErrors,
        reauthenticationCallback);


const loginCompleted = authenticatedUser => ({
    type: actionTypes.LOGIN_COMPLETED,
    authenticatedUser
});

export const login = (email, password, rememberMe, onSuccess, onErrors, reauthenticationCallback) => dispatch =>
    backend.userService.login(email, password,
        authenticatedUser => {
            dispatch(loginCompleted(authenticatedUser));
            onSuccess();
        },
        onErrors,
        reauthenticationCallback,
	rememberMe
    );


export const logout = () => {

    backend.userService.logout();

    return { type: actionTypes.LOGOUT };

};

export const updateProfileCompleted = user => ({
    type: actionTypes.UPDATE_PROFILE_COMPLETED,
    user
});

export const updateProfile = (user, onSuccess, onErrors) => dispatch =>
    backend.userService.updateProfile(user,
        user => {
            dispatch(updateProfileCompleted(user));
            onSuccess();
        },
        onErrors
    );


const addUserImageCompleted = (user) => ({
    type: actionTypes.ADD_IMAGE_COMPLETED,
    user
});

export const addUserImage = (user, file, onSuccess, onErrors) =>
    dispatch => {
        backend.userService.uploadUserImage(user, file, (result) => {
                dispatch(addUserImageCompleted(result));
                onSuccess();
            },
            onErrors);
    }
export const changePassword = (id, oldPassword, newPassword, onSuccess, onErrors) => dispatch =>
    backend.userService.changePassword(id, oldPassword, newPassword, onSuccess, onErrors);

export const getUserPoints = (userId, onSuccess, onErrors) => dispatch =>
    backend.userService.getUserPoints(userId, (points) => {
        dispatch(getUserPointsCompleted(points));
        onSuccess(points);
    },
        onErrors);

export const createJournalist = (user, onSuccess, onErrors) => dispatch =>
    backend.userService.createJournalist(user, createdUser => {
        // Si deseas almacenar el periodista recién creado en el estado, puedes hacerlo aquí
        onSuccess(createdUser);
    }, onErrors);

const getUserRankingCompleted = (ranking) => ({
    type: actionTypes.GET_USER_RANKING_COMPLETED,
    ranking
});

export const getUserRanking = (onSuccess, onErrors) => dispatch =>
    backend.userService.getUserRanking(
        (ranking) => {
            dispatch(getUserRankingCompleted(ranking));
            if (onSuccess) onSuccess(ranking);
        },
        (errors) => {
            if (onErrors) onErrors(errors);
        }
    );




export const requestPasswordChange = (
    id,
    oldPassword,
    newPassword,
    onSuccess,
    onErrors
) => dispatch =>
    backend.userService.requestPasswordChange(
        id,
        oldPassword,
        newPassword,
        onSuccess,
        onErrors
    );



// al final del archivo
export const tryLoginFromServiceToken = () => dispatch =>
  backend.userService.tryLoginFromServiceToken(
    (authenticatedUser) => {
      if (authenticatedUser) {
        dispatch({ type: actionTypes.LOGIN_COMPLETED, authenticatedUser });
      }
    },
    () => {
      // si el token es inválido/expiró, bórralo silenciosamente
      dispatch(logout());
    }
  );

const requestPasswordResetCompleted = () => ({
  type: actionTypes.REQUEST_PASSWORD_RESET_COMPLETED
});

export const requestPasswordReset = (email, onSuccess, onErrors) => dispatch =>
  backend.userService.requestPasswordReset(
    email,
    () => {
      dispatch(requestPasswordResetCompleted());
      onSuccess();
    },
    onErrors
  );

const resetPasswordCompleted = () => ({
  type: actionTypes.RESET_PASSWORD_COMPLETED
});

export const resetPassword = (token, newPassword, onSuccess, onErrors) => dispatch =>
  backend.userService.resetPassword(
    token,
    newPassword,
    () => {
      dispatch(resetPasswordCompleted());
      onSuccess();
    },
    onErrors
  );
